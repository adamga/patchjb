# Goal

Build a safe, repeatable way to enforce GitHub Copilot settings across JetBrains IDEs on Windows machines, with two operating modes:

1. Local/manual execution for development and validation.
2. Centralized deployment and enforcement through device management tools such as Intune on Windows.

The solution needs to locate JetBrains IDE config directories, update the GitHub Copilot config file in each matching profile, and do so in an idempotent way so repeated runs do not corrupt or duplicate XML.

Target files

```text
Windows: %APPDATA%\Roaming\JetBrains\<product><version>\options\github-copilot.xml
```

Desired XML content under the github-copilot component

```xml
<application>
  <component name="github-copilot">
    <option name="signinNotificationShown" value="true" />
    <option name="terminalRulesVersion" value="1" />
    <option name="toolConfirmAutoApprove" value="false" />
    <option name="trustToolAnnotations" value="false" />
    <terminalAutoApprove>
      <map />
    </terminalAutoApprove>
  </component>
</application>
```

Recommended approach

Use a script that edits XML structurally instead of doing raw text replacement.

The script should:

1. Discover JetBrains option directories by scanning the platform-specific JetBrains root.
2. Look for files matching options\<target-file-name> where the default target file name is github-copilot.xml.
3. Support an override parameter for the target file name so local testing can use github2.copilot.xml.
4. Create the file if it does not exist and the options directory exists.
5. Parse existing XML and upsert the component named github-copilot.
6. Upsert each required option by name.
7. Ensure terminalAutoApprove/map exists.
8. Preserve valid XML and write formatted output.
9. Be idempotent so running it multiple times produces the same result.
10. Support backup, dry-run, and verbose logging.

Implementation choice

Use Windows PowerShell 5.1 as the delivery baseline because that is what the customer has deployed and it aligns with Windows user-context Intune execution.

Centralized configuration strategy

Windows with Intune

Best fit: Intune Remediations or a Win32 app deployment.

Recommended pattern:

1. Detection script checks whether all discovered github-copilot.xml files contain the required values.
2. Remediation script calls the PowerShell patcher when files are missing or non-compliant.
3. Run in user context, not system context, because the target files live in the signed-in user profile under %APPDATA%.
4. Package the script with parameters locked to the production target file name github-copilot.xml.
5. Write per-profile audit logs beside the patched XML file by default.

Notes:

1. If multiple users sign into the same machine, enforcement must occur per user.
2. If JetBrains is open during remediation, either skip and retry later or patch then require restart of the IDE.
3. Intune Settings Catalog is not the right tool here because this is not a native policy-backed setting; it is an app-owned XML file.
4. The delivered solution is Windows-only and assumes Windows PowerShell 5.1.

Script design

Proposed parameters:

1. RootPath
2. TargetFileName with default github-copilot.xml
3. Backup switch
4. WhatIf switch
5. Verbose switch
6. CreateIfMissing switch

Proposed behavior:

1. Enumerate immediate JetBrains product/version directories under the root path.
2. Build candidate paths ending in options\<TargetFileName>.
3. If CreateIfMissing is enabled and options exists but the file does not, create a minimal `application` document first.
4. Load XML.
5. Ensure /application exists.
6. Ensure component[@name='github-copilot'] exists.
7. Set the required option values exactly.
8. Ensure terminalAutoApprove/map exists and is empty.
9. Save only if a change is required.
10. Return a summary of scanned, changed, skipped, and failed files.

Safety requirements

1. Never modify the live file during local testing unless the operator explicitly uses the default target file name.
2. Make backups before first write when Backup is enabled.
3. Skip malformed XML only after logging the failure clearly.
4. Treat missing JetBrains roots as a no-op, not a fatal error.
5. Consider JetBrains process detection so local testing can avoid patching while the IDE is running.

Local build and test plan

Use github2.copilot.xml as the test target so the machine's working GitHub Copilot configuration is untouched.

Plan:

1. Build the script with TargetFileName defaulting to github-copilot.xml, but always pass -TargetFileName github2.copilot.xml during local development.
2. Point the script at the real JetBrains root so discovery logic is exercised against real product/version directories.
3. Let the script create or update options\github2.copilot.xml instead of the production options\github-copilot.xml.
4. Inspect the generated test files and verify the XML shape and option values.
5. Re-run the script to confirm idempotence.
6. Test against these cases:
   a. No target file exists.
   b. Target file exists with partial settings.
   c. Target file exists with conflicting settings.
   d. Target file contains malformed XML.
7. Only after local validation, switch TargetFileName back to github-copilot.xml for managed deployment.

Suggested local commands

Windows example:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\patch-github-copilot.ps1 -RootPath "$env:APPDATA\JetBrains" -TargetFileName github2.copilot.xml -CreateIfMissing -Backup -Verbose
```

Validation checklist

1. The script discovers all expected JetBrains product/version directories.
2. Only github2.copilot.xml is created or changed during testing.
3. Existing github-copilot.xml files remain untouched.
4. Re-running the script yields no further changes when the test file is already compliant.
5. The resulting XML matches the desired component structure exactly.
6. Logs clearly show which files were scanned, changed, skipped, or failed.

Build sequence

1. Create patch-github-copilot.ps1 with the parameters and XML upsert behavior above.
2. Test locally using github2.copilot.xml.
3. Add a second detection script for Intune compliance checks if needed.
4. Package for centralized deployment.
5. Pilot on a small user set before broad rollout.

Deliverables

1. Windows PowerShell 5.1 patch script.
2. Optional detection/compliance script.
3. Deployment notes for Intune on Windows.
4. Local test evidence showing safe use of github2.copilot.xml.
