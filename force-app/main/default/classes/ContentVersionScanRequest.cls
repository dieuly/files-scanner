public with sharing class ContentVersionScanRequest {
    public String contentVersionId { get; set; }
    public String contentVersionData { get; set; }

    public ContentVersionScanRequest(String contentVersionId, String contentVersionData) {
        this.contentVersionId = contentVersionId;
        this.contentVersionData = contentVersionData;
    }
}
