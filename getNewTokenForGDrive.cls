global class getNewTokenForGDrive implements Schedulable {

    global void execute(SchedulableContext sc) {
        getNewTokenForGDrive.makecallout();
    }

    @future(callout=true)
    private static void makecallout() {
        String endpoint = 'https://oauth2.googleapis.com/token';
        String clientId = 'YOUR_CLIENT_ID_GOES_HERE';
        String clientSecret = 'YOUR_CLIENT_SECRET_GOES_HERE';
        String refreshToken = [SELECT Id, Access_Token__c, Refresh_Token__c FROM gDriveTokens__c][0].Refresh_Token__c;
        String body = 'client_secret='+clientSecret+'&grant_type=refresh_token&refresh_token='+refreshToken+'&client_id='+clientId;

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody(body);
        req.setEndpoint(endpoint);
        res=http.send(req);
        system.debug(res.getBody());

        Map<String,Object> response = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());

        gDriveTokens__c token = [SELECT Id, Access_Token__c, Refresh_Token__c FROM gDriveTokens__c][0];
        token.Access_Token__c = (String) response.get('access_token');
        update token;
    }

}
