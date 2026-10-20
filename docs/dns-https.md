# DNS and HTTPS edge

## Responsibility boundary

Four components participate in the public request path, but each solves a different problem:

| Component | Responsibility |
| --- | --- |
| Route 53 | Resolve the application hostname to the ALB through an alias record |
| ACM | Issue and renew the public certificate after domain-control validation |
| ALB | Present the certificate, terminate TLS, redirect HTTP, and route requests |
| ECS | Run the API on private task IPs; it does not own public DNS or certificates |

The resulting request path is:

```text
Client
   |
   | resolve api.example.com
   v
Route 53 public hosted zone
   |
   | A alias -> ALB
   v
internet-facing ALB
   | HTTPS :443 + ACM certificate
   | TLS terminates here
   v
IP target group
   | HTTP :8080 inside the VPC
   v
private ECS task
```

Route 53 does not run or encrypt the application. ACM does not route requests. The ALB does not run the Go process. Keeping these boundaries clear makes failures easier to diagnose.

## Prerequisites and honest defaults

HTTPS is disabled by default because a repository cannot safely invent a domain or hosted-zone ID. Before enabling it, all of the following must be true:

1. A real domain is registered.
2. Its public DNS is delegated to an existing Route 53 public hosted zone.
3. The caller can create Route 53 records and ACM certificates.
4. The chosen hostname belongs to that hosted zone.
5. The Terraform AWS provider points to the ALB region.

The module deliberately consumes an existing hosted-zone ID rather than creating a zone. Creating a second zone without updating the registrar's name-server delegation would produce records that public clients never query.

While `enable_https = false`, the ALB keeps its Phase 10 HTTP forward action and creates no certificate or DNS records. This allows infrastructure validation before a domain exists, but it is not the final production posture.

## Environment configuration

Development and production should use different hostnames even if they share one hosted zone:

```hcl
# development
enable_https            = true
application_domain_name = "api-dev.example.com"
route53_zone_id         = "Z0123456789ABCDEF"

# production
enable_https            = true
application_domain_name = "api.example.com"
route53_zone_id         = "Z0123456789ABCDEF"
```

The default listener policy is:

```hcl
tls_security_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
```

It supports modern TLS while retaining TLS 1.2 compatibility. Changing it is explicit because client compatibility and cryptographic policy should be reviewed together.

## Terraform dependency flow

When HTTPS is enabled, Terraform constructs this resource graph:

```text
ACM certificate request
        |
        v
Route 53 ACM validation CNAME
        |
        v
ACM certificate validation / issuance
        |
        v
ALB HTTPS :443 listener
        |
        v
Route 53 application A alias -> ALB
```

The HTTPS listener consumes the validated certificate ARN rather than merely the pending certificate request. The application alias depends on the HTTPS listener, so Terraform does not publish the canonical hostname before the secure entry point exists.

Certificate and ALB resources share the environment provider, so the ACM certificate is requested in the same AWS Region as the ALB. This is required for an ALB attachment.

## DNS validation

ACM proves domain control with a generated CNAME record:

```text
_token.api.example.com -> _value.acm-validations.aws
```

Terraform creates that record in the configured public hosted zone and waits up to 45 minutes for ACM to report the certificate as issued. The record must remain present after issuance: ACM uses it for managed renewal while the certificate remains eligible and associated with the load balancer.

The module currently requests exactly one hostname per environment. This keeps validation deterministic and avoids creating an unnecessarily broad wildcard certificate.

## Route 53 alias

The application record is an `A` alias:

```text
api.example.com -> ALB DNS name and canonical zone ID
```

It does not hardcode an ALB IP address. Load-balancer addresses can change while the Route 53 alias continues targeting the AWS resource. `evaluate_target_health = true` allows Route 53 to incorporate the alias target's health in DNS responses.

## Listener behavior

HTTPS traffic follows the normal target path:

```text
HTTPS :443 -> terminate TLS -> forward -> target group -> ECS :8080
```

HTTP no longer reaches the application when HTTPS is enabled:

```text
HTTP :80 -> HTTP 301 -> same host/path/query over HTTPS :443
```

For example:

```text
http://api.example.com/users?limit=10
                    |
                    v
https://api.example.com/users?limit=10
```

The redirect preserves host, path, and query. It does not proxy one plaintext request to ECS and then redirect from application code.

## TLS termination

TLS terminates at the ALB:

```text
Client -- encrypted HTTPS --> ALB -- private HTTP --> ECS
```

The ALB presents the ACM certificate and decrypts the front-end connection. ECS tasks stay private and accept traffic only from the ALB security group on port `8080`. Internal HTTP is a deliberate trade-off for this portfolio architecture; end-to-end TLS could be added for a regulatory or threat-model requirement, but would introduce internal certificate lifecycle and application-server changes.

## Security-group path

The existing chain remains unchanged:

```text
Internet -> ALB :443
Internet -> ALB :80 only to receive the redirect
ALB SG   -> ECS SG :8080
Internet -X-> ECS
Internet -X-> RDS
```

Opening `443` does not make tasks public. Both listeners are attached to the ALB, while the tasks continue to have no public IP.

## Plan and apply review

Before apply, confirm that the plan contains:

- one ACM certificate using DNS validation;
- one ACM validation CNAME in the intended public hosted zone;
- one certificate-validation waiter;
- one HTTPS listener on `443` with the expected policy;
- the existing HTTP listener changing from `forward` to `redirect` with `HTTP_301`;
- one Route 53 `A` alias pointing to the ALB;
- no public ECS IP or new ECS ingress rule;
- no certificate private key or secret output.

ACM issuance can take time because public DNS must observe the validation CNAME. A timeout is not a reason to bypass validation or use a self-signed certificate.

## Runtime validation

After a reviewed apply, retrieve the non-sensitive outputs:

```sh
APP_DOMAIN="$(terraform -chdir=terraform/environments/dev output -raw application_domain_name)"
APP_URL="$(terraform -chdir=terraform/environments/dev output -raw application_url)"
CERTIFICATE_ARN="$(terraform -chdir=terraform/environments/dev output -raw acm_certificate_arn)"
HTTPS_LISTENER_ARN="$(terraform -chdir=terraform/environments/dev output -raw alb_https_listener_arn)"
```

### 1. Confirm DNS

```sh
dig +short "$APP_DOMAIN"
```

The response should resolve through the ALB alias. Do not compare it with a permanently stored IP; ALB addresses are managed by AWS.

### 2. Confirm certificate issuance

```sh
aws acm describe-certificate \
  --certificate-arn "$CERTIFICATE_ARN" \
  --query 'Certificate.{status:Status,domain:DomainName,renewal:RenewalEligibility}'
```

Required state: `ISSUED`, with the expected hostname.

### 3. Confirm the HTTPS listener

```sh
aws elbv2 describe-listeners \
  --listener-arns "$HTTPS_LISTENER_ARN" \
  --query 'Listeners[0].{protocol:Protocol,port:Port,policy:SslPolicy,certificate:Certificates[0].CertificateArn}'
```

Required state: `HTTPS`, port `443`, expected policy and certificate ARN.

### 4. Prove the HTTP redirect

```sh
curl --head --max-redirs 0 "http://${APP_DOMAIN}/healthz"
```

Expected result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://api.example.com:443/healthz
```

The exact hostname must match the configured environment hostname. Use a path and query during evidence collection to prove they are preserved.

### 5. Prove trusted HTTPS and application routing

```sh
curl --fail --show-error --silent "${APP_URL}/healthz"
curl --fail --show-error --silent "${APP_URL}/readyz"
BASE_URL="$APP_URL" ./scripts/smoke-test.sh
```

Do not use `curl --insecure`. A successful check with certificate verification disabled is not valid HTTPS evidence.

### 6. Inspect the served certificate

```sh
openssl s_client \
  -connect "${APP_DOMAIN}:443" \
  -servername "$APP_DOMAIN" \
  -verify_return_error </dev/null
```

The hostname, certificate chain, and verification result must be valid. The `-servername` value exercises SNI as a real client would.

## Evidence to capture

Record a small set of proof after real deployment:

1. ACM certificate status `ISSUED` and hostname, without private or temporary credentials.
2. Route 53 application alias targeting the ALB.
3. HTTPS listener on `443` with its security policy.
4. `curl --head` showing HTTP `301` and the HTTPS `Location`.
5. Verified HTTPS `/healthz` returning `200` without `--insecure`.
6. `/readyz` proving the secure route reaches an API that can reach PostgreSQL.
7. Browser or `openssl` evidence showing a trusted certificate for the configured hostname.

Screenshots must include a short explanation, environment, commit SHA, and validation result. Never capture AWS credentials, certificate private material, database secrets, or complete environment dumps.

## Troubleshooting

### Certificate remains pending

Check that the hosted zone is public, the registrar delegates to its Route 53 name servers, the validation CNAME exists unchanged, and no restrictive CAA record blocks issuance. Public ACM validation cannot succeed through a private hosted zone.

### DNS returns no answer

Check the application `A` alias, hosted-zone ID, domain delegation, and whether the alias was created in the authoritative zone rather than a duplicate zone.

### TLS hostname mismatch

Compare the requested hostname with `application_domain_name` and the ACM certificate domain. Testing the raw ALB DNS name over HTTPS will not match a certificate issued for `api.example.com`.

### HTTP returns `200` instead of `301`

Confirm `enable_https = true`, inspect the port `80` listener default action, and verify the latest Terraform plan was applied.

### HTTPS returns `503`

TLS and DNS may be working while no target is healthy. Inspect target health, ECS desired/running counts, service events, and application logs. A `503` is not normally fixed by changing the certificate.

## Interview explanation

> Route 53 resolves the application hostname to the internet-facing ALB using an alias record. ACM provides a DNS-validated certificate in the same region, the ALB terminates TLS on port 443 and redirects port 80 to HTTPS, then forwards application traffic to healthy ECS task IPs in private subnets.

## References

- [Route traffic to an ELB load balancer](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html)
- [ACM DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
- [Certificates for an Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html)
- [Create an HTTPS listener](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html)
