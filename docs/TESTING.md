# Testing

## Build and preview

Run `make all` with Pandoc installed. Check that `index.html` includes the
expected content, dates, and link destinations. Run `make server` and open
`http://localhost:8000/` to preview the rendered page.

## Deploy

Set `CF_DISTRIBUTION_ID` or put the distribution ID in the local
`distribution_name` file. Use `make -n update_page` to inspect the upload and
invalidation commands.

An authorized publish uses `make update_page` and the `deploy` AWS CLI profile.
The command prints the uploaded S3 version ID and CloudFront invalidation ID,
then waits for the invalidation to complete. Fetch `https://raycoll.com/` and
compare the response with the generated `index.html`.

If the upload succeeded but invalidation failed, retry the CloudFront
invalidation for `/` and `/index.html` using the same deploy profile. To roll
back, have a site administrator retrieve the previous S3 object version, upload
it as the current `index.html`, and invalidate those paths.
