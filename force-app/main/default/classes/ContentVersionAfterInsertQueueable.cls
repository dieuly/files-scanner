public with sharing class ContentVersionAfterInsertQueueable implements Queueable, Database.AllowsCallouts {
    private Set<Id> contentVerionIds;
    private static final Integer REQUEST_TIMEOUT = 60000;
    private static final Integer STATUS_CODE_SUCCESS = 200;

    public ContentVersionAfterInsertQueueable(Set<Id> contentVerionIds) {
        this.contentVerionIds = contentVerionIds;
    }

    public void execute(QueueableContext context) {
        List<ContentVersionScanResponse> contentVersionScanResponses = new List<ContentVersionScanResponse>();
        List<ContentVersion> versions = [
            SELECT
                Id,
                VersionData
            FROM ContentVersion
            WHERE Id IN :contentVerionIds
            LIMIT 1000    
        ];

        Content_Version_Settings__c cvSettings = Content_Version_Settings__c.getInstance();
        for (ContentVersion version : versions) {
            contentVersionScanResponses.add(
                sendContentVersionData(new ContentVersionScanRequest(version.Id, version.VersionData.toString()),
                cvSettings.Heroku_Endpoint_URL__c
            ));
        }

        Set<String> restrictedURLs = new Set<String>();
        List<Disallowed_URL__mdt> disallowedURLs = Disallowed_URL__mdt.getAll().values();
        for (Disallowed_URL__mdt url : disallowedURLs) {
            restrictedURLs.add(url.Label);
        }

        List<ContentVersion> contentVersionUpdateList = new List<ContentVersion>();
        for (ContentVersionScanResponse contentWrapper : contentVersionScanResponses) {
            if (contentWrapper != null) {
                Boolean disallowedURLFound = false;
                for (String url : contentWrapper.urlsList) {
                    if (restrictedURLs.contains(url)) {
                        disallowedURLFound = true;
                        break;
                    }
                }
                if (disallowedURLFound) {
                    contentVersionUpdateList.add(
                        new ContentVersion(
                            Id = contentWrapper.contentVersionId, 
                            Harmful_File__c = true
                        )
                    );
                }
            }
        }
        if (!contentVersionUpdateList.isEmpty()) {
            update contentVersionUpdateList;
        }
    }

    private static ContentVersionScanResponse sendContentVersionData(ContentVersionScanRequest wrapper, String url) { 
        HttpResponse response = invokeScanUrls(url, JSON.serialize(wrapper));
        return handleContentVersionScanResponse(response);
    }

    private static ContentVersionScanResponse handleContentVersionScanResponse(HttpResponse response) {
        if (response.getStatusCode() == STATUS_CODE_SUCCESS) {
            return (ContentVersionScanResponse)JSON.deserialize(response.getBody(), ContentVersionScanResponse.class);
        } else {
            return null;
        }
    }

    // invoke http request
    private static HttpResponse invokeScanUrls(String endPointUrl, String jsonMessageBody) {
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(endPointURL);
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(REQUEST_TIMEOUT);
        request.setBody(jsonMessageBody);
        HttpResponse response = new Http().send(request);
        return response;
    }
}
