# ContactCRM — Infrastructure & Architecture

Live site: **https://sales.awesomeblackbusiness.com**
Infrastructure as code: [`web/infra/terraform`](./terraform) · Content deploys: [`web/deploy.sh`](../deploy.sh)

## Diagram

```mermaid
flowchart TB
    subgraph Client["📱 User Device (Browser)"]
        UI["ContactCRM SPA<br/>HTML / CSS / JS"]
        WC["WebCrypto AES-GCM<br/>non-extractable key"]
        IDB[("IndexedDB<br/>encryption key")]
        LS[("localStorage<br/>encrypted CRM blob")]
        DIAL["Call queue →<br/>tel: / FaceTime / Skype / WhatsApp"]
        UI --> WC --> IDB
        WC --> LS
        UI --> DIAL
    end

    subgraph Google["🔑 Google"]
        GSI["Google Identity Services<br/>(sign-in, identity only)"]
    end

    subgraph AWS["☁️ AWS — account 306499034564 / us-east-1"]
        R53["Route 53<br/>sales.awesomeblackbusiness.com<br/>A-ALIAS"]
        CF["CloudFront<br/>E2SWY5YFIV3RV9<br/>HTTPS, SPA fallback"]
        ACM["ACM cert<br/>TLS 1.2+"]
        OAC["Origin Access Control"]
        S3[("S3 bucket<br/>private, OAC-only<br/>static site files")]
        R53 --> CF
        ACM -.-> CF
        CF --> OAC --> S3
    end

    UI -->|"HTTPS GET"| R53
    UI -->|"ID token (not stored/sent)"| GSI

    subgraph IaC["🛠️ Infra as Code"]
        TF["Terraform<br/>web/infra/terraform"]
        DEP["deploy.sh<br/>S3 sync + CF invalidation"]
    end
    TF -.->|"manages"| AWS
    DEP -.->|"publishes files"| S3
```

## How it fits together

| Layer | Component | Notes |
|---|---|---|
| **DNS** | Route 53 `A`-ALIAS | `sales.awesomeblackbusiness.com` → CloudFront (zone `ZQKDSIZ3XJDSM`) |
| **CDN / TLS** | CloudFront `E2SWY5YFIV3RV9` | HTTPS redirect, TLS 1.2+, SPA 403→`/index.html` fallback |
| **Certificate** | ACM (us-east-1) | DNS-validated for the domain |
| **Origin** | S3 bucket `sales.awesomeblackbusiness.com` | Private; reachable only via CloudFront Origin Access Control |
| **Auth** | Google Identity Services | Sign-in for identity only; the ID token is decoded client-side and never stored or sent to a server |
| **Data** | Browser `localStorage` + WebCrypto | Whole CRM document AES-GCM encrypted; key is a non-extractable `CryptoKey` in IndexedDB |
| **Dialing** | Device app URL schemes | `tel:` / FaceTime / Skype / WhatsApp — launched by the browser, connected by one user tap |

## Trust boundaries

- **Nothing leaves the browser** except static-asset fetches from CloudFront and
  the Google sign-in exchange. There is no application backend and no network
  entitlement for CRM data.
- **CRM data at rest** is encrypted in `localStorage`; the key never exists in
  script-readable form.
- **S3 is never public** — only CloudFront (via OAC) can read objects.

## Change management

- **Infrastructure** changes → edit [`terraform/main.tf`](./terraform/main.tf), `terraform apply`.
- **Site content** changes → run [`web/deploy.sh`](../deploy.sh) (S3 sync + CloudFront invalidation).
