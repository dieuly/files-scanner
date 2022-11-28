@IsTest(SeeAllData=false)
public class ContentVersionTriggerTest {

    private static final String VERSION_TITLE = 'Title';
    private static final String VERSION_DATA = 'Version Data content URL ';

    @TestSetup
    static void createTestData() {
        Content_Version_Settings__c cvSettings = new Content_Version_Settings__c (
            Heroku_Endpoint_URL__c = 'Test Endpoint URL'
        );
        insert cvSettings;
        System.assertNotEquals(null, cvSettings.Id, 'Record inserted and id should not be null');
    }

    static testMethod void testFileUploadWithoutHarmfulContent() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ContentVersionScanMockClean());

        String versionData = VERSION_DATA + 'https://www.supercool.com';
        ContentVersion contentVersion = createContentVersion(VERSION_TITLE, versionData);
        insert contentVersion;
        System.assertNotEquals(null, contentVersion.Id, 'Record inserted and id should not be null');

        Test.stopTest();
        System.assertEquals(1, queryContentVersion().size(), 'File should be found because no harmful content');
    }

    static testMethod void testFileUploadWithHarmfulContent() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ContentVersionScanMockHarmful());

        List<Disallowed_URL__mdt> disallowedURLs = Disallowed_URL__mdt.getAll().values();
        String versionData = VERSION_DATA + disallowedURLs.get(0).Label;
        ContentVersion contentVersion = createContentVersion(VERSION_TITLE, versionData);
        insert contentVersion;
        System.assertNotEquals(null, contentVersion.Id, 'Record inserted and id should not be null');

        Test.stopTest();
        System.assertEquals(0, queryContentVersion().size(), 'File should not be found because of harmful content');
    }

    static testMethod void testFileUploadError() { 
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ContentVersionScanMockError());

        ContentVersion contentVersion = createContentVersion(VERSION_TITLE, 'Testing');
        insert contentVersion;
        System.assertNotEquals(null, contentVersion.Id, 'Record inserted and id should not be null');

        Test.stopTest();
        System.assertEquals(1, queryContentVersion().size(), 'File should be found because integration failed');
     }

    private static ContentVersion createContentVersion(String title, String dataString) {
        return new ContentVersion(
                Title = title,
                PathOnClient = title,
                VersionData = Blob.valueOf(dataString),
                IsMajorVersion = true
        );
    }

    private static List<ContentVersion> queryContentVersion() {
        return [
                SELECT Id,
                        Harmful_File__c
                FROM ContentVersion
                WHERE Title = :VERSION_TITLE
                LIMIT 1
        ];
    }

    private class ContentVersionScanMockClean implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'JSON');
            response.setBody(JSON.serialize(responseClean()));
            return response;
        }
    }

    private static ContentVersionScanResponse responseClean() {
        ContentVersion contentVersion = queryContentVersion().get(0);
        return new ContentVersionScanResponse(contentVersion.Id, new List<String>());
    }

    private class ContentVersionScanMockHarmful implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'JSON');
            response.setBody(JSON.serialize(responseHarmful()));
            return response;
        }
    }

    private static ContentVersionScanResponse responseHarmful() {
        ContentVersion contentVersion = queryContentVersion().get(0);
        List<Disallowed_URL__mdt> disallowedURLs = Disallowed_URL__mdt.getAll().values();
        return new ContentVersionScanResponse(
            contentVersion.Id, 
            new List<String>{ disallowedURLs.get(0).Label }
        );
    }

    private class ContentVersionScanMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setHeader('Content-Type', 'JSON');
            response.setBody('Error');
            return response;
        }
    }
}