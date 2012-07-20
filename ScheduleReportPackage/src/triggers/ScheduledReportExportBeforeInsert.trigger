trigger ScheduledReportExportBeforeInsert on Scheduled_Report_Export__c (before insert) {
	ScheduleReportExport.setName(trigger.new);
}