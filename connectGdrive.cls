public with sharing class connectGdrive {

    
    public Static Pagereference AccessToken(){
        
        String endpoint = 'https://oauth2.googleapis.com/token';
        String clientId = '635212851248-sjpidvddvpfe99q74sp54hp266d699e8.apps.googleusercontent.com';
        String clientSecret = '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';
        String redirectURI = 'https://jeevantechnologies-6f-dev-ed--c.develop.vf.force.com/apex/gDrive';
        String authCode = Apexpages.currentPage().getParameters().get('Code');
        String authHeader = 'Basic '+EncodingUtil.base64Encode(Blob.valueOf(clientId+':'+clientSecret));
        String body = 'code='+authCode+'&client_id=635212851248-sjpidvddvpfe99q74sp54hp266d699e8.apps.googleusercontent.com&client_secret=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&scope=https://www.googleapis.com/auth/drive&grant_type=authorization_code&redirect_uri='+redirectURI;

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', authHeader);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);
        req.setEndpoint(endpoint);
        res=http.send(req);
        system.debug(res.getBody());

        Map<String,Object> response = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());

        gDriveTokens__c token = [SELECT Id, Access_Token__c, Refresh_Token__c FROM gDriveTokens__c][0];
        token.Access_Token__c = (String) response.get('access_token');
        token.Refresh_Token__c = (String) response.get('refresh_token');
        update token;

        Pagereference refreshPage = new Pagereference('/apex/gDrive');
        return refreshPage;

    }

}