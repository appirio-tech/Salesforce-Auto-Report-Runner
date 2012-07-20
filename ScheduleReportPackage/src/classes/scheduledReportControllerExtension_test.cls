@isTest
private class scheduledReportControllerExtension_test {
	
	public class customException extends Exception{}
	
	private static User createTestUser(String surname) {
		Profile p = [select id from profile LIMIT 1];
	    
	    User u = new User(alias = 'standt', email='standarduser@testorg.com', 
	            emailencodingkey='UTF-8', lastname=surname, 
	            languagelocalekey='en_US', 
	            localesidkey='en_US', profileid = p.Id,
	            timezonesidkey='America/Los_Angeles', 
	            username=surname + '@testorg.com');

	    insert u;
	    
	    return u;
	}
	
	private static Scheduled_Report_Export__c createTestScheduledReportExport(String frequency, String hour, User u) {
		//dependent on data here - single report should be part of package
        List<Report> reports = [SELECT Id, Name FROM Report LIMIT 1];
        if (reports.size()<=0) throw new customException('No report to use for unit test');
        
        //dependent on data here - template should be part of package
		List<EmailTemplate> template = [SELECT Id, Name FROM EmailTemplate WHERE DeveloperName = 'Default_Template'];
		if (template.size()<=0) throw new customException('No EmailTemplate to use for unit test');
		
		Scheduled_Report_Export__c schReports = new Scheduled_Report_Export__c();
        schReports.Name = reports[0].name;
        schReports.Report_Id__c = reports[0].Id;
        schReports.Email_Template_Id__c = template[0].Id;
        schReports.Frequency__c = frequency;
        schReports.Day_of_the_week__c = 'Every day';
        if (hour==null) {
        	schReports.Preferred_Time_of_Day__c = DateTime.Now().hour() + ':00';
        } else {
        	schReports.Preferred_Time_of_Day__c = hour + ':00';
        }
        schReports.Save_Result__c = true;
        schReports.Start_Date__c = date.today();
        schReports.End_Date__c = date.today();
        schReports.Active__c = true;
        if (u!=null) schReports.UncommittedRecipientUser__c = string.valueOf(u.Id)+','+u.lastname+';null,ceo@salesforce.com';
        insert schReports;
        
        return schReports;
	}
	
    static testMethod void test_loadEditPage() {
    	
    	Scheduled_Report_Export__c schReport = createTestScheduledReportExport('Daily', null, null);
        PageReference pr = Page.editScheduledReportExport;        
        ApexPages.StandardController sc = new ApexPages.StandardController(schReport);
        scheduledReportExportControllerExtension ext = new scheduledReportExportControllerExtension(sc);
        Test.setCurrentPageReference(pr);
        
        String pageURL = pr.getUrl();
        system.assertEquals('/apex/editscheduledreportexport', pageURL);
        
        system.assertEquals('Edit', ext.getContext());
        
        List<SelectOption> templates = ext.getEmailTemplateSelectList();
        system.assertNotEquals(0, templates.size());
        
        List<SelectOption> reports = ext.getReportSelectList();
        system.assertNotEquals(0, reports.size());
        
        Report report = ext.getReport();
        system.assertNotEquals(null, report);
        
        //TODO add asserts
        PageReference ref = ext.startExportReport();
        ext.setName();
    }

    static testMethod void test_addRecipient() {
    	//will add and then remove 1 recipient
    	
    	User recipient1 = createTestUser('testRecipient');
    	
    	Scheduled_Report_Export__c schReport = createTestScheduledReportExport('Daily', null, null);
        PageReference pr = Page.editScheduledReportExport;        
        ApexPages.StandardController sc = new ApexPages.StandardController(schReport);
        scheduledReportExportControllerExtension ext = new scheduledReportExportControllerExtension(sc);
        Test.setCurrentPageReference(pr);
        
        String pageURL = pr.getUrl();
        system.assertEquals('/apex/editscheduledreportexport', pageURL);
        
        List<Scheduled_Report_Export_Recipient__c> recipients = ext.getRecipients();
        system.assertEquals(0, recipients.size());
        
        ext.recipientId = recipient1.Id;
        ext.recipientName = recipient1.Name;
        ext.addRecipient();
        
        //these values get cleared once recipinets been created
        system.assertEquals(null, ext.recipientId);
        system.assertEquals(null, ext.recipientName);
        
        recipients = ext.getRecipients();
        system.assertEquals(1, recipients.size());
        system.assertNotEquals(null, recipients[0]);
        
        ext.recipientRemoveId = recipients[0].Id;
        ext.removeRecipient();
        
        recipients = ext.getRecipients();
        system.assertEquals(0, recipients.size());
    }
}