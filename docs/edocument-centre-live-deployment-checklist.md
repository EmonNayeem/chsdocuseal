# eDocument Centre Live Deployment Checklist

> [!WARNING]  
> **THIS DOCUMENT IS A PLAN ONLY.**  
> Do not execute it until deployment day.  
> Do not include any secrets or passwords in this document.

## 1. Current Live State
- **Current public URL**: `https://chsdocuseal.churchfieldhomeservices.ie`
- **Future public URL**: `https://edc.churchfieldhomeservices.ie`
- **Current live Docker container name**: `docuseal`
- **Current live host port**: `6968`
- **Current live Docker image tag**: `chs-docuseal:chs-custom-v1`
- **Current live Docker volume**: `docuseal`
- **Current live server build folder**: `~/builds/chsdocuseal`

## 2. Pre-deployment Stop Points
- [ ] Confirm GitHub CI is green.
- [ ] Confirm repository is on the latest commit/tag on `chs-custom-v1`.
- [ ] Confirm backups are created.
- [ ] Confirm Nginx Proxy Manager (NPM) and DNS access are available.
- [ ] Confirm rollback commands are ready.
> [!IMPORTANT]  
> Explicit warning: No DNS/domain cutover should occur until *after* the application container is confirmed healthy and working on the old domain.

## 3. Backup Checklist
- [ ] Backup the Docker volume (`docuseal`).
- [ ] Backup the current image and container metadata.
- [ ] Record current container environment values.
- [ ] Record current Nginx Proxy Manager settings.
- [ ] Record current DNS settings.

## 4. Build Checklist on Live Ubuntu VM
- [ ] Pull the latest code.
- [ ] Checkout the `chs-custom-v1` branch.
- [ ] Verify the expected latest commit is active.
- [ ] Build the new Docker image with a new tag (e.g., `chs-docuseal:edocument-centre-phase-5`).
- [ ] **Do not** overwrite the old image tag yet.

## 5. Test-Container Checklist (Before Replacing Live Container)
> [!NOTE]  
> Do not touch the live volume during these test container steps.

- [ ] Use a separate temporary volume.
- [ ] Use a separate temporary host port (e.g., `6970`).
- [ ] Use temporary `HOST` and `APP_URL` environment values.
- [ ] Spin up the temporary test container.
- [ ] Perform a `curl` health check.
- [ ] Perform a browser smoke test if possible (e.g., tunneling to port 6970).
- [ ] Remove the temporary test container and temporary volume after testing.

## 6. Production Replacement Checklist
- [ ] Stop the existing live container only after backup and test image succeed.
- [ ] Run the new container using the existing `docuseal` volume.
- [ ] Keep the host port as `6968` initially.
- [ ] Keep the old domain (`chsdocuseal.churchfieldhomeservices.ie`) initially to verify the application upgrade safely.
- [ ] Proceed to smoke tests using the old domain to ensure the app functions properly.

## 7. Domain Cutover Checklist
- [ ] Update DNS for `edc.churchfieldhomeservices.ie`.
- [ ] Update Nginx Proxy Manager with the new domain and valid SSL certificates.
- [ ] Update Docker container environment values:
  ```env
  HOST=https://edc.churchfieldhomeservices.ie
  EMAIL_HOST=edc.churchfieldhomeservices.ie
  APP_URL=https://edc.churchfieldhomeservices.ie
  ```
- [ ] Restart the container to apply the new domain configuration.
- [ ] Run a final smoke test on the new domain.

## 8. Smoke Tests
- [ ] Login successfully.
- [ ] Ensure existing templates are visible under "Materials Direct".
- [ ] Verify the company list is visible to a platform admin.
- [ ] Ensure users are correctly scoped by their company.
- [ ] Validate that department restrictions still function properly.
- [ ] Upload a PDF.
- [ ] Create a template.
- [ ] Send a signature request.
- [ ] Complete the signing link workflow.
- [ ] Confirm email links utilize the expected domain (`edc.churchfieldhomeservices.ie`).
- [ ] Ensure "eDocument Centre" display text appears where appropriate.
- [ ] Verify the per-company SMTP settings page loads.
- [ ] Ensure branding settings save successfully.

## 9. Rollback Plan
- [ ] Stop the new container.
- [ ] Restore the old container, image, and environment values.
- [ ] Keep the existing `docuseal` volume (unless a migration rollback is explicitly required and verified).
- [ ] Revert Nginx Proxy Manager and DNS to the old domain if the domain cutover was already executed.
> [!CAUTION]  
> **Rollback Principle:** Do not delete any backups until the application has been entirely stable for several days.

## 10. Final Sign-off Checklist
- [ ] No critical errors are present in the docker logs.
- [ ] The public application functions perfectly.
- [ ] The email sending test is successful.
- [ ] The document signing test is successful.
- [ ] All backups are safely retained.
- [ ] The old Docker image is safely retained.
