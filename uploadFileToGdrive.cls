public with sharing class uploadFileToGdrive {
    
    public static void fileUploadHandler(List<ContentVersion> cvFileList) {
        for (ContentVersion cvFile : cvFileList) {
            ContentVersion contentVersion = [SELECT Id, ContentDocument.Title, VersionData, FileType FROM ContentVersion WHERE ContentDocumentId = :cvFile.contentDocumentId ORDER BY CreatedDate DESC LIMIT 1];
            System.debug(contentVersion.FileType);
            //To get the name of the object where the file has been uploaded
            List<ContentDocumentLink> links = [SELECT LinkedEntityId, ShareType, Visibility FROM ContentDocumentLink WHERE ContentDocumentId = :cvFile.contentDocumentId];
            if (links.isEmpty()) {
                System.debug('No linked records found for ContentDocumentId: ' + cvFile.contentDocumentId);
                return;
            }
            Id linkedEntityId;
            for (ContentDocumentLink var : links) {
                if (var.ShareType == 'V') {
                    linkedEntityId = var.LinkedEntityId;
                }
            }
            // Next, query the linked object to get its type
            SObject linkedObject = Database.query('SELECT Id, Name FROM ' + linkedEntityId.getSObjectType() + ' WHERE Id = \'' + linkedEntityId + '\'');
            if (linkedObject == null) {
                System.debug('Linked object not found for Id: ' + linkedEntityId);
                return;
            }
            // Finally, get the object name from the linked object's SObjectType
            String objectNameForFolder = linkedObject.getSObjectType().getDescribe().getLabel();
            uploadFileToGdrive.uploadFileCallout(MIMEHelper.getMIMEType(contentVersion.FileType), contentVersion.VersionData, contentVersion.ContentDocument.Title, objectNameForFolder);
        }
    }

    @future(callout=true)
    public static void uploadFileCallout(String contentType, Blob fileData, String fileName, String objectNameForFolder) {
        String fileId, folderId;
        //Find folder - If found it'll return the folder Id & If not it'll return no folder found
        HttpRequest searchFolderRequest = new HttpRequest();
        searchFolderRequest.setMethod('GET');
        searchFolderRequest.setEndpoint('https://www.googleapis.com/drive/v3/files');
        searchFolderRequest.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
        String query = 'q=' + EncodingUtil.urlEncode('mimeType=\'application/vnd.google-apps.folder\' and trashed = false and name=\''+objectNameForFolder+'\'', 'UTF-8') + 
                    '&fields=' + EncodingUtil.urlEncode('nextPageToken, files(id, name)', 'UTF-8');
        searchFolderRequest.setEndpoint(searchFolderRequest.getEndpoint() + '?' + query);
        Http searchFolderHTTP = new Http();
        HttpResponse searchFolderResponse = searchFolderHTTP.send(searchFolderRequest);
        if (searchFolderResponse.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(searchFolderResponse.getBody());
            List<Object> files = (List<Object>) response.get('files');
            if (!files.isEmpty()) {
                Map<String, Object> folder = (Map<String, Object>) files.get(0);
                folderId = (String)folder.get('id');
            } 
            else {
                //create folder in Google Drive
                Http createFolderHTTP = new Http();
                HttpRequest createFolderReq = new HttpRequest();
                createFolderReq.setMethod('POST');
                createFolderReq.setEndpoint('https://www.googleapis.com/drive/v3/files');
                createFolderReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
                createFolderReq.setHeader('Content-Type', 'application/json');
                createFolderReq.setHeader('Accept', 'application/json');
                createFolderReq.setBody('{"name":"'+objectNameForFolder+'","mimeType":"application/vnd.google-apps.folder"}');
                HttpResponse createFolderRes = createFolderHTTP.send(createFolderReq);
                if (createFolderRes.getStatusCode() == 200) {
                    Map<String, Object> responseJson = (Map<String, Object>) JSON.deserializeUntyped(createFolderRes.getBody());
                    folderId = (String) responseJson.get('id');
                }
                else {
                    System.debug('Error moving file: ' + createFolderRes.getStatusCode() + ' ' + createFolderRes.getStatus());
                }
            }
        }
        else {
            System.debug('Request failed with status code ' + searchFolderResponse.getStatusCode());
        }

        //Upload the document to the Google Drive
        Http uploadFileHTTP = new Http();
        HttpRequest uploadFileReq = new HttpRequest();
        uploadFileReq.setMethod('POST');
        uploadFileReq.setEndpoint('https://www.googleapis.com/upload/drive/v3/files?uploadType=media');
        uploadFileReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
        uploadFileReq.setHeader('Content-Type', contentType);
        uploadFileReq.setBodyAsBlob(fileData);
        HttpResponse uploadFileRes = uploadFileHTTP.send(uploadFileReq);
        //Update the file name after uploading the document
        if (uploadFileRes.getStatusCode() == 200) {
            Map<String, Object> responseJson = (Map<String, Object>) JSON.deserializeUntyped(uploadFileRes.getBody());
            fileId = (String) responseJson.get('id');
            Http renameHTTP = new Http();
            HttpRequest renameReq = new HttpRequest();
            renameReq.setMethod('PATCH');
            renameReq.setEndpoint('https://www.googleapis.com/drive/v3/files/' + fileId);
            renameReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
            renameReq.setHeader('Content-Type', 'application/json');
            renameReq.setBody('{"name": "' + fileName + '"}');
            HttpResponse renameRes = renameHTTP.send(renameReq);
            if (renameRes.getStatusCode() == 200) {
                //Move uploaded file to the found folder.
                Http moveFileHTTP = new Http();
                HttpRequest moveFileReq = new HttpRequest();
                moveFileReq.setMethod('POST');
                moveFileReq.setEndpoint('https://www.googleapis.com/drive/v2/files/'+fileId+'/parents');
                moveFileReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
                moveFileReq.setHeader('Content-Type', 'application/json');
                moveFileReq.setHeader('Accept', 'application/json');
                moveFileReq.setBody('{"id":"'+folderId+'"}');
                HttpResponse moveFileRes = moveFileHTTP.send(moveFileReq);
                if (moveFileRes.getStatusCode() == 200) {
                    System.debug('File moved successfully');
                }
                else {
                    System.debug('Error moving file: ' + moveFileRes.getStatusCode() + ' ' + moveFileRes.getStatus());
                }
            }
            else {
                System.debug('Error updating file name: ' + renameRes.getBody());
            }
        }
        else {
            System.debug('Error uploading file: ' + uploadFileRes.getBody());
        }
    }

}