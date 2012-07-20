trigger ScheduledReportExportBeforeUpdate on Scheduled_Report_Export__c (before update) {
	ScheduleReportExport.setName(trigger.new);
}