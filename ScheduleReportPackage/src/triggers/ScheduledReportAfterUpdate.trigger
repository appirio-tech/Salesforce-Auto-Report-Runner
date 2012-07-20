trigger ScheduledReportAfterUpdate on Scheduled_Report_Export__c (after update) {
	ScheduleReportExport.commitRecipients(trigger.new);
}