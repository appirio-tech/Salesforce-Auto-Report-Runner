@isTest
private class ScheduleReportExport_test {
	
	public class customException extends Exception{}
	
	public static User createTestUser(String surname) {
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
	
	public static Scheduled_Report_Export__c createTestScheduledReportExport(String frequency, String hour, User u) {
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
	
	
	 
	static testMethod void test_autoCompleteController() {
		User u = createTestUser('autoCompleteController');
		
		SObject[] objs = autoCompleteController.findSObjects('User', 'autoComplete', 'LastName');
		
		system.assertNotEquals(0, objs.size());
	}
	
    static testMethod void test_runScheduledReports() {
        User u = createTestUser('mahood');
        Scheduled_Report_Export__c schReports = createTestScheduledReportExport('Daily', null, u);
        
        Test.StartTest();      
        
        ScheduleReportExport sre = new ScheduleReportExport(); 
		sre.runScheduledReports();
        
        Test.StopTest();
        
        List<Scheduled_Report_Export_Job__c> jobs = [SELECT Id, Status__c FROM Scheduled_Report_Export_Job__c WHERE Scheduled_Report_Export__c = :schReports.Id];
        system.assertEquals('Success', jobs[0].status__c);
    }
	static testMethod void test_runScheduledReports_Fail() {
        Test.StartTest(); 
        
        Scheduled_Report_Export__c schReports = createTestScheduledReportExport('Daily', null, null);
        Map<Id, Id> mapJobs = ScheduleReportExport.createJobHistories(new List<Scheduled_Report_Export__c>{schReports}, 'Manual');
        Id jobId = mapJobs.get(schReports.Id);
		system.assertNotEquals(null, jobId);
		
		Id reportId = schReports.Report_Id__c;

        ScheduleReportExport.doExport('123', jobId, schReports.Id, reportId, schReports.Name, null, null, false);
        
        Test.StopTest();
        
        List<Scheduled_Report_Export_Job__c> jobs = [SELECT Id, Status__c FROM Scheduled_Report_Export_Job__c WHERE Id = :jobId];
        system.assertEquals('Failed', jobs[0].status__c);
    }
    
    static testMethod void test_isCorrectHour() {
        Scheduled_Report_Export__c schReportsCorrectHour = createTestScheduledReportExport('Daily', null, null);
        Integer previousHour = DateTime.Now().hour()-1;
        Scheduled_Report_Export__c schReportsWrongHour = createTestScheduledReportExport('Daily', String.valueOf(previousHour), null);
        
        Test.StartTest();      
        
        ScheduleReportExport sre = new ScheduleReportExport(); 
		system.assertEquals(true, sre.isCorrectHour(schReportsCorrectHour.Preferred_Time_of_Day__c));		
		system.assertEquals(false, sre.isCorrectHour(schReportsWrongHour.Preferred_Time_of_Day__c));   
        Test.StopTest();
    }
    static testMethod void test_isCorrectFreq_Daily() {
        ScheduleReportExport sre = new ScheduleReportExport(); 
		system.assertEquals(true, sre.isCorrectFrequency('Daily', 'Every day', false));		
    }
    static testMethod void test_isCorrectFreq_Weekly() {
        ScheduleReportExport sre = new ScheduleReportExport(); 
		system.assertEquals(true, sre.isCorrectFrequency('Weekly', 'Every day', true));		
    }
    static testMethod void test_isCorrectFreq_Monthly() {
        ScheduleReportExport sre = new ScheduleReportExport(); 
		system.assertEquals(true, sre.isCorrectFrequency('Monthly', null, true));		
    }
    static testMethod void test_isCorrectFreq_Error() {
        ScheduleReportExport sre = new ScheduleReportExport(); 
		system.assertEquals(false, sre.isCorrectFrequency('CRAP', null, false));		
    }
    
    static testMethod void test_handleRedirectRequest() {
        ExportReport report = new ExportReport();
		String sid = report.handleRedirectRequest('http:www.google.com/', ExportReport.TestPath.REDIRECT);
		system.assertEquals('123456789', sid);
    }
    static testMethod void test_handleRedirectRequest_InvalidRedirect() {
        ExportReport report = new ExportReport();
		Exception expectedEx = null;
        try {
			String sid = report.handleRedirectRequest('http:www.google.com/', ExportReport.TestPath.REDIRECT_ERROR);
        } catch (Exception ex) {
        	expectedEx = ex;
        }
        
        system.assertNotEquals(null, expectedEx); //exception should have been raised
		system.assertEquals('Unkown Error: Redirect during login with no redirect location', expectedEx.getMessage());
    }
    static testMethod void test_handleRedirectRequest_ERROR() {
        ExportReport report = new ExportReport();
		Exception expectedEx = null;
        try {
			String sid = report.handleRedirectRequest('http:www.google.com/', ExportReport.TestPath.ERROR);
        } catch (Exception ex) {
        	expectedEx = ex;
        }
        
        system.assertNotEquals(null, expectedEx); //exception should have been raised
		system.assertEquals('Unkown Error: Unhandled response from web service, Web Service Response: System.HttpResponse[Status=ERROR, StatusCode=404]', expectedEx.getMessage()); 
    }
    static testMethod void test_runReport_OKCSV() {
        Scheduled_Report_Export__c schReports = createTestScheduledReportExport('Daily', null, null);
        ExportReport report = new ExportReport();
		Blob reportCSV = report.getReportAsCSV(schReports.Report_Id__c, ExportReport.TestPath.OK_CSV);
		system.assertEquals('IT WORKS!', reportCSV.toString());
    }
    static testMethod void test_runReport_OKNONCSV() {
        Scheduled_Report_Export__c schReports = createTestScheduledReportExport('Daily', null, null);
        ExportReport report = new ExportReport();
        Exception expectedEx = null;
        try {
			Blob reportNonCSV = report.getReportAsCSV(schReports.Report_Id__c, ExportReport.TestPath.OK_NONCSV);
        } catch (Exception ex) {
        	expectedEx = ex;
        }
        
        system.assertNotEquals(null, expectedEx); //exception should have been raised
		system.assertEquals('Unkown Error: Unexpected content type returned: text/html; charset=UTF-8', expectedEx.getMessage()); 
    }
    static testMethod void test_runReport_ERROR() {
        Scheduled_Report_Export__c schReports = createTestScheduledReportExport('Daily', null, null);
        ExportReport report = new ExportReport();
        Exception expectedEx = null;
        try {
			Blob reportNonCSV = report.getReportAsCSV(schReports.Report_Id__c, ExportReport.TestPath.ERROR);
        } catch (Exception ex) {
        	expectedEx = ex;
        }
        
        system.assertNotEquals(null, expectedEx); //exception should have been raised
		system.assertEquals('Unkown Error: Unhandled response from web service, Web Service Response: System.HttpResponse[Status=ERROR, StatusCode=404]', expectedEx.getMessage()); 
    }
}