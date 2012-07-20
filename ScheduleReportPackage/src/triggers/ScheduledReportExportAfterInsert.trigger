trigger ScheduledReportExportAfterInsert on Scheduled_Report_Export__c (after insert) {
	ScheduleReportExport.commitRecipients(trigger.new);
}