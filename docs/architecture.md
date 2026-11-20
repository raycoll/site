# Site architecture

```mermaid
flowchart LR
    Source["index.md"] -->|Pandoc| Build["index.html"]
    Build -->|MFA-gated website-deploy role| Bucket["Private S3 bucket<br/>Versioned index.html"]
    CDN["CloudFront<br/>Default root object index.html"] -->|Origin access identity| Bucket
    Visitors -->|HTTPS| CDN
    Deploy["make update_page"] -->|Invalidate / and /index.html| CDN
```

The deploy role writes the homepage object and requests a cache invalidation
on the site distribution. CloudFront distribution configuration and bucket
settings are managed separately from publishing. S3 keeps earlier revisions
of the homepage for rollback.
