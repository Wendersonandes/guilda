# Active Storage & Direct Uploads

Uploads (profile/group `avatar` and `cover_image`) use **Active Storage direct uploads**: the
browser uploads the file straight to the storage service and submits only the signed blob id.

## Configuration

- Development/test: `Disk` (`config/storage.yml`, `config.active_storage.service = :local`).
- Production: S3 (`:amazon`), selected via `config/environments/production.rb`:
  `ENV.fetch("ACTIVE_STORAGE_SERVICE", "amazon").to_sym`.
- Credentials: `aws.access_key_id` / `aws.secret_access_key` (`bin/rails credentials:edit`).
- The S3 adapter gem is `aws-sdk-s3` (`require: false`).

## JavaScript

- `@rails/activestorage` is pinned to `activestorage.esm.js` and started in
  `app/javascript/application.js` (`ActiveStorage.start()`).
- Fields use `direct_upload: true` (see `app/views/shared/_image_upload_field.html.erb`).
- A Stimulus controller (`direct_upload_controller.js`) shows a local preview and a progress bar
  using the `direct-upload:*` events.

Direct uploads work in development with the `Disk` service (uploads go through the Rails app),
so **no CORS is needed locally**.

## Required for production (S3)

Direct uploads PUT the file to the bucket **from the browser**, so the bucket needs CORS and the
credentials need write/read/delete permissions.

### Bucket CORS

Replace `https://guilda.art` (and add `www`, staging, etc.) with your real origins:

```json
[
  {
    "AllowedHeaders": ["Content-Type", "Content-MD5", "x-amz-acl", "x-amz-*"],
    "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
    "AllowedOrigins": ["https://guilda.art", "https://www.guilda.art"],
    "ExposeHeaders": ["ETag", "Location"],
    "MaxAgeSeconds": 3000
  }
]
```

### IAM policy

Attach to the credentials user (scope `Resource` to the bucket/prefix):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::guilda-bucket",
        "arn:aws:s3:::guilda-bucket/*"
      ]
    }
  ]
}
```

## Constraints

- Allowed image types: **PNG, JPEG, WebP**; max size **5 MB**
  (`Actor::ALLOWED_IMAGE_TYPES`, `Actor::MAX_IMAGE_SIZE`). Enforced server-side on attach; the
  `accept` attribute on the input is a client convenience only.

## Notes

- With direct upload the blob is uploaded before the model is saved; if a validation fails the
  orphaned blob is cleaned up by `ActiveStorage::Blob`'s purge job
  (`bin/rails active_storage:purge_unattached` for a manual sweep).
- If you later enable a Content Security Policy with nonces/Trusted Types, revisit the editor
  (Lexxy) and any inline styles.
