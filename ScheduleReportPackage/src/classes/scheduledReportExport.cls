global class scheduledReportExport implements Schedulable{
	
	/*to scheduled to run every hour
	
	scheduledReportExport sRE = new scheduledReportExport();
    String sch = '0 0 /1 * * ?';
    system.schedule('ScheduledReportExport', sch, sRE);
    */
	
	
	global void execute(SchedulableContext SC) {
		
		try {
			ScheduleReportExport sre = new ScheduleReportExport(); 
			sre.runScheduledReports();	
		} catch (Exception ex) {
			system.debug('scheduledReportExport...execute...ex' + ex);
		}
	}
}