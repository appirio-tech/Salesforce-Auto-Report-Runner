global with sharing class SingleReportExport {
	
	WebService static void exportReport(string id) {
		ScheduleReportExport reportExport = new ScheduleReportExport();
		reportExport.runSingleReport(id);
	}

}