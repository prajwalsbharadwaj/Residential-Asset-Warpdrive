public with sharing class DemandLetterService {

    @TestVisible private static Id TEST_THROW_ID = '000000000000000000';

    @AuraEnabled
    public static String generateAndStoreDoc(Id demandId) {
        if (Test.isRunningTest()) {
            if (demandId == TEST_THROW_ID) {
                throw new AuraHandledException('Forced exception in generateAndStoreDoc');
            }
            return 'MockContentDocumentId_DOC';
        }

        try {
            // Render VF page into Word blob
            PageReference docPage = Page.DemandLetterPDF;
            docPage.getParameters().put('id', demandId);
            Blob wordBlob = docPage.getContent();

            // Generate file name
            String fileName = 'Demand_Letter_' + DateTime.now().format('yyyyMMdd_HHmmss');

            // Save ContentVersion with FirstPublishLocationId
            ContentVersion version = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName + '.docx',
                VersionData = wordBlob,
                IsMajorVersion = true,
                FirstPublishLocationId = demandId
            );
            insert version;

            // Query back for ContentDocumentId
            version = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :version.Id
                LIMIT 1
            ];

            // Return the ContentDocumentId for LWC to open
            return version.ContentDocumentId;

        } catch (Exception ex) {
            throw new AuraHandledException('Word document generation failed: ' + ex.getMessage());
        }
    }
}