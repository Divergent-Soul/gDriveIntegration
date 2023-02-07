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
            SObject linkedObject = Database.query('SELECT Id FROM ' + linkedEntityId.getSObjectType() + ' WHERE Id = \'' + linkedEntityId + '\'');
            if (linkedObject == null) {
                System.debug('Linked object not found for Id: ' + linkedEntityId);
                return;
            }
            // Finally, get the object name from the linked object's SObjectType
            String objectNameForFolder = linkedObject.getSObjectType().getDescribe().getLabel();
            system.debug(objectNameForFolder);
            String recordIdentifier;
            if (objectNameForFolder == 'Case') {
                List<Case> temp = [SELECT Id, Subject FROM Case WHERE Id=:linkedEntityId];
                recordIdentifier = temp[0].Subject+' - '+temp[0].Id;
            }
            else {
                List<sObject> temp = Database.query('SELECT Id, Name FROM '+objectNameForFolder+' Where Id = \''+linkedEntityId+'\'');
                recordIdentifier = temp[0].get('Name')+' - '+temp[0].Id;
            }
            uploadFileToGdrive.uploadFileCallout(MIMEHelper.getMIMEType(contentVersion.FileType), contentVersion.VersionData, contentVersion.ContentDocument.Title, objectNameForFolder, recordIdentifier);
        }
    }

    @future(callout=true)
    public static void uploadFileCallout(String contentType, Blob fileData, String fileName, String objectNameForFolder, String RecordId) {
        String fileId, objectFolderId, recordFolderId;
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
                objectFolderId = (String)folder.get('id');
                HttpRequest searchRecordFolderRequest = new HttpRequest();
                searchRecordFolderRequest.setMethod('GET');
                searchRecordFolderRequest.setEndpoint('https://www.googleapis.com/drive/v3/files');
                searchRecordFolderRequest.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
                String query1 = 'q=' + EncodingUtil.urlEncode('mimeType=\'application/vnd.google-apps.folder\' and trashed = false and name=\''+RecordId+'\'', 'UTF-8') + 
                            '&fields=' + EncodingUtil.urlEncode('nextPageToken, files(id, name)', 'UTF-8');
                searchRecordFolderRequest.setEndpoint(searchRecordFolderRequest.getEndpoint() + '?' + query1);
                Http searchRecordFolderHTTP = new Http();
                HttpResponse searchRecordFolderResponse = searchRecordFolderHTTP.send(searchRecordFolderRequest);
                if (searchRecordFolderResponse.getStatusCode() == 200) {
                    Map<String, Object> response1 = (Map<String, Object>) JSON.deserializeUntyped(searchRecordFolderResponse.getBody());
                    List<Object> files1 = (List<Object>) response1.get('files');
                    if (!files1.isEmpty()) {
                        Map<String, Object> folder1 = (Map<String, Object>) files1.get(0);
                        recordFolderId = (String)folder1.get('id');
                    } 
                    else {
                        //create folder in Google Drive
                        Http createRecordFolderHTTP = new Http();
                        HttpRequest createRecordFolderReq = new HttpRequest();
                        createRecordFolderReq.setMethod('POST');
                        createRecordFolderReq.setEndpoint('https://www.googleapis.com/drive/v3/files');
                        createRecordFolderReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
                        createRecordFolderReq.setHeader('Content-Type', 'application/json');
                        createRecordFolderReq.setHeader('Accept', 'application/json');
                        createRecordFolderReq.setBody('{"name":"'+RecordId+'","mimeType":"application/vnd.google-apps.folder"}');
                        HttpResponse createRecordFolderRes = createRecordFolderHTTP.send(createRecordFolderReq);
                        if (createRecordFolderRes.getStatusCode() == 200) {
                            Map<String, Object> responseJson1 = (Map<String, Object>) JSON.deserializeUntyped(createRecordFolderRes.getBody());
                            recordFolderId = (String) responseJson1.get('id');
                            //Move uploaded file to the found folder.
                            Http moveFileHTTP = new Http();
                            HttpRequest moveFileReq = new HttpRequest();
                            moveFileReq.setMethod('POST');
                            moveFileReq.setEndpoint('https://www.googleapis.com/drive/v2/files/'+recordFolderId+'/parents');
                            moveFileReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
                            moveFileReq.setHeader('Content-Type', 'application/json');
                            moveFileReq.setHeader('Accept', 'application/json');
                            moveFileReq.setBody('{"id":"'+objectFolderId+'"}');
                            HttpResponse moveFileRes = moveFileHTTP.send(moveFileReq);
                            if (moveFileRes.getStatusCode() == 200) {
                                System.debug('File moved successfully');
                            }
                            else {
                                System.debug('Error moving file: ' + moveFileRes.getStatusCode() + ' ' + moveFileRes.getStatus());
                            }
                        }
                        else {
                            System.debug('Error moving file: ' + createRecordFolderRes.getStatusCode() + ' ' + createRecordFolderRes.getStatus());
                        }
                    }
                }
                else {
                    System.debug('Request failed with status code ' + searchRecordFolderResponse.getStatusCode());
                }
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
                    objectFolderId = (String) responseJson.get('id');
                    //create folder in Google Drive
                    Http createRecordFolderHTTP = new Http();
                    HttpRequest createRecordFolderReq = new HttpRequest();
                    createRecordFolderReq.setMethod('POST');
                    createRecordFolderReq.setEndpoint('https://www.googleapis.com/drive/v3/files');
                    createRecordFolderReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
                    createRecordFolderReq.setHeader('Content-Type', 'application/json');
                    createRecordFolderReq.setHeader('Accept', 'application/json');
                    createRecordFolderReq.setBody('{"name":"'+RecordId+'","mimeType":"application/vnd.google-apps.folder"}');
                    HttpResponse createRecordFolderRes = createRecordFolderHTTP.send(createRecordFolderReq);
                    if (createRecordFolderRes.getStatusCode() == 200) {
                        Map<String, Object> responseJson1 = (Map<String, Object>) JSON.deserializeUntyped(createRecordFolderRes.getBody());
                        recordFolderId = (String) responseJson1.get('id');
                        //Move uploaded file to the found folder.
                        Http moveFileHTTP = new Http();
                        HttpRequest moveFileReq = new HttpRequest();
                        moveFileReq.setMethod('POST');
                        moveFileReq.setEndpoint('https://www.googleapis.com/drive/v2/files/'+recordFolderId+'/parents');
                        moveFileReq.setHeader('Authorization', 'Bearer ' + [SELECT Access_Token__c FROM gDriveTokens__c LIMIT 1][0].Access_Token__c);
                        moveFileReq.setHeader('Content-Type', 'application/json');
                        moveFileReq.setHeader('Accept', 'application/json');
                        moveFileReq.setBody('{"id":"'+objectFolderId+'"}');
                        HttpResponse moveFileRes = moveFileHTTP.send(moveFileReq);
                        if (moveFileRes.getStatusCode() == 200) {
                            System.debug('File moved successfully');
                        }
                        else {
                            System.debug('Error moving file: ' + moveFileRes.getStatusCode() + ' ' + moveFileRes.getStatus());
                        }
                    }
                    else {
                        System.debug('Error moving file: ' + createRecordFolderRes.getStatusCode() + ' ' + createRecordFolderRes.getStatus());
                    }
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
                moveFileReq.setBody('{"id":"'+recordFolderId+'"}');
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
