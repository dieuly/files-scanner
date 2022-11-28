public with sharing class ContentVersionScanResponse {
    public String contentVersionId { get; set; }
    public List<String> urlsList { get; set; }

    public ContentVersionScanResponse(String contentVersionId, List<String> urlsList) {
        this.contentVersionId = contentVersionId;
        this.urlsList = urlsList;
    }
}
