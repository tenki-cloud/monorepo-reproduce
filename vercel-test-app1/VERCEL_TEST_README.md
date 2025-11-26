# Vercel Rate Limit Test Setup

This test setup helps reproduce and investigate potential rate limiting issues when deploying to Vercel from Tenki runners vs GitHub-hosted runners.

## Problem Statement

A client reported that deploying multiple projects to Vercel simultaneously works fine with GitHub-hosted runners but hits rate limits when using Tenki runners. The hypothesis is that Tenki runners share the same IP address, causing Vercel's API to throttle requests.

## Test Structure

- **5 minimal Next.js apps** (`vercel-test-app1` through `vercel-test-app5`)
- **Workflow** that deploys all 5 apps in parallel
- **Two runner types** to compare: Tenki runners vs GitHub-hosted runners

## Setup Instructions

### 1. Create Vercel Account & Projects

1. **Sign up for Vercel** (if you don't have an account):
   - Go to https://vercel.com/signup
   - Use your GitHub account to sign up

2. **Create 5 Vercel projects** (one for each test app):
   ```bash
   # Navigate to each app and link it to Vercel
   cd vercel-test-app1
   npx vercel link
   # Follow the prompts to create a new project
   
   # Repeat for each app
   cd ../vercel-test-app2
   npx vercel link
   
   # ... and so on for app3, app4, app5
   ```

   **Alternative:** Let the workflow create projects automatically on first deploy (simpler but less control)

3. **Get your Vercel credentials**:
   - **Vercel Token**: https://vercel.com/account/tokens
     - Click "Create Token"
     - Give it a descriptive name (e.g., "GitHub Actions Test")
     - Copy the token
   
   - **Org ID**: After linking projects, check any `.vercel/project.json` file:
     ```bash
     cat vercel-test-app1/.vercel/project.json
     # Look for "orgId": "team_xxx" or "usr_xxx"
     ```

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository:
1. Go to: Settings → Secrets and variables → Actions
2. Add the following secrets:

```
VERCEL_TOKEN=<your-vercel-token>
VERCEL_ORG_ID=<your-org-or-user-id>
```

**Optional:** If you linked projects manually, add project IDs:
```
VERCEL_PROJECT_ID_vercel-test-app1=<project-id-1>
VERCEL_PROJECT_ID_vercel-test-app2=<project-id-2>
VERCEL_PROJECT_ID_vercel-test-app3=<project-id-3>
VERCEL_PROJECT_ID_vercel-test-app4=<project-id-4>
VERCEL_PROJECT_ID_vercel-test-app5=<project-id-5>
```

### 3. Run the Test

1. **Navigate to Actions tab** in your GitHub repository
2. **Select** "Vercel Rate Limit Test" workflow
3. **Click** "Run workflow"
4. **Choose** which runner to test:
   - `tenki-standard-autoscale` - Test only Tenki runners
   - `ubuntu-latest` - Test only GitHub-hosted runners
   - `both` - Test both and compare (recommended)

### 4. Analyze Results

Look for these indicators in the workflow logs:

#### Signs of Rate Limiting:
- ❌ **HTTP 429 errors** (Too Many Requests)
- ⏱️  **Significantly longer deployment times** on Tenki vs GitHub
- 🔄 **Retry attempts** or "throttled" messages
- ⚠️  **"Concurrent build limit exceeded"** errors
- 💤 **Queuing behavior** where deployments wait

#### What's Normal:
- ✅ All deployments complete successfully
- ✅ Similar timing between Tenki and GitHub runners
- ✅ No error messages about limits or throttling

#### IP Address Analysis:
```bash
# Check the logs for "Runner IP:" output
# Tenki runners should show: SAME or very similar IPs
# GitHub runners should show: DIFFERENT IPs for each job
```

## Expected Outcomes

### Scenario A: IP-based Rate Limiting Confirmed
- ❌ Tenki runners: Multiple failures or slow deployments
- ✅ GitHub runners: All succeed quickly
- 📊 Result: Vercel is likely rate-limiting based on shared IP

### Scenario B: Concurrent Build Limits
- ❌ Both runners: Some failures with "concurrent build limit" messages
- 📊 Result: Vercel account has concurrent deployment limits (check Enhanced Builds settings)

### Scenario C: No Rate Limiting
- ✅ Both runners: All deployments succeed
- 📊 Result: Issue might be specific to client's setup or has been resolved

## Troubleshooting

### Issue: Deployments fail with "Project not found"
**Solution:** Manually link each app to Vercel first:
```bash
cd vercel-test-app1
npx vercel link
```

### Issue: "VERCEL_TOKEN is not set"
**Solution:** Check GitHub secrets are properly configured at:
Settings → Secrets and variables → Actions

### Issue: All deployments succeed (can't reproduce)
**Try these variations:**
1. Increase number of apps (create app6, app7, app8...)
2. Trigger multiple workflow runs simultaneously
3. Deploy during peak hours when rate limits might be stricter
4. Check if client's Vercel plan has different limits than yours

## Next Steps

After running the test:
1. **Share logs** with your manager showing the results
2. **Compare** Tenki vs GitHub runner outcomes
3. **Document findings** in the Linear issue
4. If rate limiting is confirmed:
   - Contact Vercel support with evidence
   - Explore workarounds (sequential deployments, rate limiting in workflow, etc.)
   - Consider using GitHub runners for Vercel deployments specifically

## Cleanup

To clean up after testing:
1. Delete the 5 Vercel projects from your dashboard
2. Remove the test workflow file
3. Delete the vercel-test-app1-5 directories
