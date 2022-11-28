public with sharing class ContentVersionTriggerHandler {

    public static void afterInsert(List<ContentVersion> contentVersions) {
        Set<Id> cvIds = gatherContentVersionIds(contentVersions);
        System.enqueueJob(new ContentVersionAfterInsertQueueable(cvIds));
    }

    public static void afterUpdate(List<ContentVersion> contentVersions, Map<Id, ContentVersion> contentVersionsOldMap) {
        deleteHarmfulFile(contentVersions, contentVersionsOldMap);
    }

    private static Set<Id> gatherContentVersionIds(List<ContentVersion> contentVersions) {
        Set<Id> cvIds = new Set<Id>();
        for (ContentVersion cv : contentVersions) {
            cvIds.add(cv.Id);
        }
        return cvIds;
    }

    public class ContentDocumentDeleteWrapper {
        public Id userId { get; set; }
        public String fileTitle { get; set; }

        public ContentDocumentDeleteWrapper(ContentVersion contentVersion) {
            this.userId = contentVersion.CreatedById;
            this.fileTitle = contentVersion.Title;
        }
    }

    private static void deleteHarmfulFile(List<ContentVersion> contentVersions, Map<Id, ContentVersion> contentVersionsOldMap) {
        Map<Id, ContentDocumentDeleteWrapper> contentDocumentDeleteMap = new Map<Id, ContentDocumentDeleteWrapper>();
        for (ContentVersion cv : contentVersions) {
            if (cv.Harmful_File__c 
                && cv.Harmful_File__c != contentVersionsOldMap.get(cv.Id).Harmful_File__c) {
                    contentDocumentDeleteMap.put(cv.ContentDocumentId, new ContentDocumentDeleteWrapper(cv));
            }
        }

        if (!contentDocumentDeleteMap.isEmpty()) {
            List<ContentDocument> contentDocumentDeleteList = new List<ContentDocument>();
            for (Id cvId : contentDocumentDeleteMap.keySet()) {
                contentDocumentDeleteList.add(new ContentDocument(Id = cvId));
            }
            delete contentDocumentDeleteList;
            sendNotificationEmails(contentDocumentDeleteMap.values());
        }   
    }

    private static void sendNotificationEmails(List<ContentDocumentDeleteWrapper> contentDocumentDeleteWrapperList) {
        List<Messaging.SingleEmailMessage> emailMessageList = new List<Messaging.SingleEmailMessage>();
        
        for (ContentDocumentDeleteWrapper cdw : contentDocumentDeleteWrapperList) {
            emailMessageList.add(createEmailMessage(
                buildEmailSubject(),
                buildEmailBody(cdw.fileTitle),
                cdw.userId
            ));
        }
        Messaging.sendEmail(emailMessageList, false);
    }

    private static Messaging.SingleEmailMessage createEmailMessage(String emailSubject, String emailBody, Id receiver) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject(emailSubject);
        mail.setHtmlBody(emailBody);
        mail.setTargetObjectId(receiver);
        mail.setSaveAsActivity(false);
        return mail;
    }

    private static String buildEmailSubject() { 
        return 'Your uploaded file was deleted due to harmful content';
    }

    private static String buildEmailBody(String fileTitle) {
        return 
            '<div>' +
                '<p>Hello,</p>' +
                '<p>' +
                    'For your information, '+
                    'file named <b>' + fileTitle + '</b> which you has uploaded in Salesforce was removed because it contained disallowed URL(s).' +
                '</p>' +
                '<br/>'+
                '<p>Best regards,</p>'+
                '<p>Salesforce Support</p>' +
            '</div>';
    } 
}
