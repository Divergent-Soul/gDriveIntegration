public with sharing class connectGdrive {

    
    public Static Pagereference AccessToken(){
        
        String endpoint = 'https://oauth2.googleapis.com/token';
        String clientId = 'YOUR_CLIENT_ID_GOES_HERE';
        String clientSecret = 'YOUR_CLIENT_SECRET_GOES_HERE';
        String redirectURI = 'YOUR_VF_PAGE_LINK_GOES_HERE';
        String authCode = Apexpages.currentPage().getParameters().get('Code');
        String authHeader = 'Basic '+EncodingUtil.base64Encode(Blob.valueOf(clientId+':'+clientSecret));
        String body = 'code='+authCode+'&client_id=YOUR_CLIENT_ID_GOES_HERE&client_secret=YOUR_CLIENT_SECRET_GOES_HERE&scope=https://www.googleapis.com/auth/drive&grant_type=authorization_code&redirect_uri='+redirectURI;

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
