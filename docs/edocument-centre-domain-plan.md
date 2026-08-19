# eDocument Centre Domain Migration Plan

> [!WARNING]  
> **DO NOT APPLY THESE CHANGES UNTIL DEPLOYMENT DAY.**  
> This document outlines the infrastructure changes required to cut over to the new domain. Making these changes prematurely will break the live environment.

## Overview
- **Current live domain**: `chsdocuseal.churchfieldhomeservices.ie`
- **Future domain**: `edc.churchfieldhomeservices.ie`

## Required Infrastructure Changes

### 1. DNS Change
- Create a new `A` record (or `CNAME`) for `edc.churchfieldhomeservices.ie` pointing to the same IP address as the current `chsdocuseal.churchfieldhomeservices.ie`.

### 2. Nginx Proxy Manager (NPM) Change
- Access the NPM admin dashboard.
- Edit the proxy host currently serving `chsdocuseal.churchfieldhomeservices.ie`.
- Update the **Domain Names** field to `edc.churchfieldhomeservices.ie` (you may choose to keep the old domain as an alias for a redirection if needed, but primary should be the new domain).
- Ensure an SSL certificate is generated and assigned for `edc.churchfieldhomeservices.ie`.

### 3. Docker / Container Environment Values
Update the environment variables on the production server where the Docker container runs. Change the following values in your `.env` or deployment configuration:
```env
HOST=https://edc.churchfieldhomeservices.ie
EMAIL_HOST=edc.churchfieldhomeservices.ie
APP_URL=https://edc.churchfieldhomeservices.ie
```
Restart the container to apply the new environment variables.

## Required Smoke Tests
After the cutover, perform the following verification steps on the live server:
1. Load `https://edc.churchfieldhomeservices.ie` in a browser and ensure the app loads without SSL errors.
2. Log into the application as an admin.
3. Verify that all branding reads **eDocument Centre**.
4. Create and send a test signature request.
5. Verify the received email contains links pointing to `https://edc.churchfieldhomeservices.ie` and the from/reply-to headers reflect the new configurations.
6. Complete the test document and ensure the final redirect or completion page loads successfully on the new domain.

## Rollback Plan
If any critical issues arise during the domain cutover, follow these steps to revert:
1. Revert the **Docker/container env values** back to their original state:
   ```env
   HOST=https://chsdocuseal.churchfieldhomeservices.ie
   EMAIL_HOST=chsdocuseal.churchfieldhomeservices.ie
   APP_URL=https://chsdocuseal.churchfieldhomeservices.ie
   ```
2. Restart the container.
3. Revert the **Nginx Proxy Manager host** back to serving `chsdocuseal.churchfieldhomeservices.ie` primarily.
4. Verify the application operates correctly on the old domain.
