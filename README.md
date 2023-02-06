# gDriveIntegration

Goal:
To upload all the files that has been uploaded to Salesforce org via Notes & Attachments to the connected Google Drive with seperate folders for each object.



Source:

1. Apex Trigger file with name "uploadFileToGdriveTriggerOnContentVersion.trigger" - This will be executed whenever a "ContentVersion" has been created into the salesforce system and It'll call a trigger handler class named "uploadFileToGdrive.cls"
2. Apex Class for trigger handler with name "uploadFileToGdrive.cls" - This class holds the over all folder validation, folder creation, file upload and renaming processes.
3. Apex Class for mimeType conversion helper with name "MIMEHelper.cls" - This class is a helper to convert the file types info mimeType which is passed into the API calls to setup the file type in google drive
4. Schedule Apex Class for getting new token every 1 hour using refresh token with name "getNewTokenForGDrive.cls" - Since the access token has a validity of 60 mins, schedule this class for every 1 hour which will refresh the access token.
5. Visual Force Page with the name "gDrive.page" - It acts as a landing page for the initial API call to get the access token & refresh token for the 1st time.
6. Apex class with the name "connectGdrive.cls" = It is the helper for the VF Page to catch the Authorization ID and make another API callout to get the access token & refresh token and store them to a custom object.
7. Create a dummy VF page named closePage for redirection after getting the Authorization Code.
Note: Using a Custom Object "gDriveTokens__c" with two custom fields "Access_Token__c" & "Refresh_Token__c"


Hit this link once to get the access token (change the redirect_uri with your VF page link). Once refresh token are received, it will be stored in the custom object and it is valid for 7 days:

https://accounts.google.com/o/oauth2/v2/auth
?redirect_uri=https://jeevantechnologies-6f-dev-ed--c.develop.vf.force.com/apex/gDrive
&prompt=consent
&response_type=code
&client_id=635212851248-sjpidvddvpfe99q74sp54hp266d699e8.apps.googleusercontent.com
&scope=https://www.googleapis.com/auth/drive
&access_type=offline
