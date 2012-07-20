public with sharing class ScheduleReportExport {
	
	/*
	Example:
	ScheduleReportExport schReport = new ScheduleReportExport();
	schReport.runScheduledReports();
	*/
	
	public class customException extends Exception{}
	public static String complianceEmail = Properties.getComplianceEmail;
	public static Boolean ccCompliance = Properties.isComplianceEnabled;
	public static String manualLabel = 'Manual';
	public static String scheduledLabel = 'Scheduled';
	
	public void runScheduledReports() {
		//return all jobs that are active and in date
		List<Scheduled_Report_Export__c> schReports = [SELECT Id, Name, OwnerId, Owner.Email, Report_Id__c, Frequency__c, Day_of_the_week__c, Preferred_Time_of_Day__c, Send_to_me__c, Email_Template_Id__c, Save_Result__c
													   FROM Scheduled_Report_Export__c 
													   WHERE Active__c = true AND 
													   (Start_Date__c <= TODAY AND End_Date__c >= TODAY)];
		
		List<Scheduled_Report_Export__c> schReportsToExe = new List<Scheduled_Report_Export__c>();											   
	    
	    //loops through all scheduled reports returned and checks for validaity prior to execution
	    for (Scheduled_Report_Export__c schReport : schReports) {
	    	System.debug('runScheduledReports...schReport...' + schReport);
	    	//checks the frequency of the job
	   		if (isCorrectFrequency(schReport.Frequency__c, schReport.Day_of_the_week__c, false)) {
	   			//check if correct hour of day
	   			if (isCorrectHour(schReport.Preferred_Time_of_Day__c)) {
	   				schReportsToExe.add(schReport);
	   			}
	   		}  
	    }
	    
	    executeReportExports(schReportsToExe, scheduledLabel);
	}
	
	public void runSingleReport(Id scheduledReportId) {
		//running a single report ignores all frequency checks and gets marked as manual
		List<Scheduled_Report_Export__c> schReports = [SELECT Id, Name, OwnerId, Owner.Email, Active__c, Report_Id__c, Frequency__c, Day_of_the_week__c, Preferred_Time_of_Day__c, Send_to_me__c, Email_Template_Id__c, Save_Result__c
													   FROM Scheduled_Report_Export__c 
													   WHERE Id = :scheduledReportId LIMIT 1];
													   
		executeReportExports(schReports, manualLabel);
	}
	
	private void executeReportExports(List<Scheduled_Report_Export__c> schReportsToExecute, String ExecutionMethod) {
		system.debug('READYTOEXPORT...' + schReportsToExecute);
		Map<Id, Id> mapScheduledEmailIdJobId = new Map<Id, Id>();
		
		try {
			//created the job history record as a receipt of the transaction
			mapScheduledEmailIdJobId = createJobHistories(schReportsToExecute, ExecutionMethod);
		} catch (Exception ex) {
			throw new customException('UNKNOWN_ERROR, ERROR: ' + ex.getMessage());
		}
		
		try {
			List<Id> scheduledEmailIds = new List<Id>();	    
		    
		    for (Scheduled_Report_Export__c schReport : schReportsToExecute) {
		    	system.debug('executeReportExports...schReport.Id...' + schReport.Id);
		    	system.debug('executeReportExports...mapScheduledEmailIdJobId...' + mapScheduledEmailIdJobId);
		    	
		    	Id jobId = mapScheduledEmailIdJobId.get(schReport.Id);
		    	
		    	if (jobId != null) {
		    		//executes future method one at a item for each job, each job has own future call
	    			doExport(UserInfo.getSessionId(), jobId, schReport.Id, schReport.Report_Id__c, schReport.Name, getToAddresses(schReport), schReport.Email_Template_Id__c, schReport.Save_Result__c);
		    	} else {
		    		system.debug('JOB_NOT_CREATED');
		    		throw new customException('JOB_NOT_CREATED');
		    	}
		    }
		} catch (Exception ex) {
			throw new customException('UNKNOWN_ERROR, ERROR: ' + ex.getMessage());
		}
	    
	}
	
	public boolean isCorrectHour(String preferredTimeOfDay) {
		//verifies that the current time is the time of day set on the job
		
		boolean retVal = false;
		integer timeOfDay = Integer.valueOf(preferredTimeOfDay.substring(0, 2));
		
		system.debug('isCorrectHour...timeOfDay...' + timeOfDay);
		system.debug('isCorrectHour...DateTime.Now().hour()...' + DateTime.Now().hour());
		
		if (DateTime.Now().hour() == timeOfDay) {
   			retVal = true;
   		} else {
   			system.debug('NOTSCHEDULED_FOR_CURRENT_HOUR');
   		}
   		
   		return retVal;
	}
	
	public boolean isCorrectFrequency(String frequency, String dayOfWeek, Boolean alwaysFire) {
		//verifies that the date matches the frequency
		boolean retVal = false;
		
		if (frequency.equals('Daily') || frequency.equals('Weekly')) {
			//if daily or weekly then check which days to run
			//could select daily but only choose monday
			//chould select weekly and select everyday
			
			//could tidy this logic up for in future
   			retVal = isCorrectDay(dayOfWeek, alwaysFire);
   		} else if (frequency.equals('Monthly')) {
   			//if freq is monthly then will run on first day of month only
   			if (date.today().toStartOfMonth() == date.today() || alwaysFire) {
				retVal = true;
   			} else {
   				system.debug('NOTSCHEDULED_FOR_CURRENT_MONTH');
   			}
   		} else {
   			system.debug('UNKNOWN_FREQUENCY');
   		}
   		
   		return retVal;
	}
	
	private boolean isCorrectDay(String daysOfWeek, Boolean alwaysFire) {
		//checks the multiselect list to ensure the job is only executed on specfic days
		boolean retVal = false;
		if (alwaysFire) retVal = true;
		
		system.debug('isCorrectDay...daysOfWeek...' + daysOfWeek);
		
		if (daysOfWeek!=null) {
			//split out options from multiselect
			String[] daysOfWeekList = daysOfWeek.split(';');
			
			for(String dayOfWeek : daysOfWeekList) {
				system.debug('isCorrectDay...dayOfWeek...' + dayOfWeek);
				
				if (!retVal) {
					if (dayOfWeek.equals('Every day')) {
						retVal = true;
					} else if (dayOfWeek.equals('Weekdays')) {
						//if weekdays then will run uf not sat or sun
			   			if (DateTime.now().format('EEEE') != 'Satruday' &&  DateTime.now().format('EEEE') != 'Sunday') {
			   				retVal = true;
			   			}
			   		} else if (DateTime.now().format('EEEE') == dayOfWeek) {
						retVal = true;
			   		} else {
			   			system.debug('UNKNOWN_DAYOFWEEK');
			   		}
				}			
			}		
		} else {
			throw new customException('Day of week not defined');
		}
   		
   		return retVal;
	}
	
	public Set<String> getToAddresses(Scheduled_Report_Export__c schReport) {
		//retrives the email from the owner and from all recipients
		
		Set<String> toAddresses = new Set<String> {};
		
		if (schReport != null) {
			if (schReport.Send_to_me__c == true) {
				system.debug('getToAddresses...AddingOwner...' + schReport.Owner.Email);
				toAddresses.add(schReport.Owner.Email);
			}
			
			//get recipients
			List<Scheduled_Report_Export_Recipient__c> recipients = [SELECT Id, Name, Recipient__c, Recipient__r.Email, Custom_Email__c
																		FROM Scheduled_Report_Export_Recipient__c
																		WHERE Scheduled_Report_Export__c = :schReport.Id];
			
			system.debug('getToAddresses...recipients...' + recipients);
			
			if (recipients != null) {
				for (Scheduled_Report_Export_Recipient__c recipient : recipients) {
					//we can either have a user lookup or just an email address
					//this supports emailing non sf users
					
					system.debug('getToAddresses...recipient...' + recipient);
					if (recipient.Recipient__c != null) {
						system.debug('getToAddresses...addRecipientEmail...' + recipient.Recipient__r.Email);
						toAddresses.add(recipient.Recipient__r.Email);
					} else if (recipient.Custom_Email__c != null) {
						system.debug('getToAddresses...addCustomEmail...' + recipient.Recipient__r.Email);
						toAddresses.add(recipient.Custom_Email__c);
					} else {
						system.debug('getToAddresses...nothing to add');
					}
				}
			}
		}
		
		system.debug('getToAddresses...toAddresses...' + toAddresses);
		
		return toAddresses;
	}
	
	
	/*
	Consideration...
	Salesforce imposes a limit on the number of future method invocations: 
	200 method calls per full Salesforce user license per 24 hours. 	
	*/
	
	@future (callout=true)
	public static void doExport(String sid, Id jobId, Id scheduledEmailId, Id reportId, String reportName, Set<String> toAddresses, String emailTemplateId, Boolean saveResult) {
		
		try {
			//checks that an action is defined - eiter email or save results
			if ((toAddresses == null || toAddresses.size()==0) && !saveResult) {
				throw new customException('NO_ACTION_DEFINED');
			}
			
			ExportReport report = new ExportReport();
			//return the blobcsv file to be attached and saved
			Blob reportCSV = report.getReportAsCSV(reportId, null);
			
			//runs the report without headers and scrapes the results to include in body of emails
			//report scrapping will be added to end of any template
			String reportHTML = report.getReportAsHTML(reportId, null);
			
			//sends email with attachment and report scrapping
			sendReportAsEmail(reportCSV, reportName, reportHTML, toAddresses, emailTemplateId);
			
			//updates job record as successful
			setJobHistorySuccess(jobId, reportCSV, reportName, saveResult, toAddresses);
		} catch (Exception ex) {
			system.debug('doExportToEmail...ex...' + ex);
			setJobHistoryFailure(jobId, ex.getMessage());
		}	
	}
	
	private static void sendReportAsEmail(Blob reportBlob, String reportName, String reportHTML, Set<String> toAddresses, Id EmailTemplateId) {
		system.debug('sendReportAsEmail...toAddresses...' + toAddresses);

		try {
			//check that we are sending it to someone or if compliance want to be ccd
			if ((toAddresses != null && toAddresses.size() > 0)  || ccCompliance) {			
				Messaging.reserveSingleEmailCapacity(toAddresses.size());
					
				//creating email attachment
				Messaging.EmailFileAttachment reportAttachment = new Messaging.EmailFileAttachment();
				reportAttachment.setFileName(reportName + '.csv');
				reportAttachment.setContentType('text/csv'); //set type to csv
				reportAttachment.setBody(reportBlob);
				
				String[] arrToAddresses = new String[]{};
				arrToAddresses.addAll(toAddresses);
				String[] ccAddresses = new String[] {complianceEmail};
					
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setToAddresses(arrToAddresses);
				//added option to define compliance email address so they can monitor external sends
				if (ccCompliance) mail.setCcAddresses(ccAddresses);
				
				mail.setFileAttachments(new Messaging.EmailFileAttachment[] {reportAttachment});
				
				//LIMITATIONL: salesforce cannot send an email using toAddresses when a template is defined
				//as a work around i query the template and set the body of the template as the email body
				//merge fields DO NOT get merged - they will be sent as they appear on the template
				//additional work could be done to handle merging to a degree
				
				EmailTemplate template;
				if (EmailTemplateId != null) {
					List<EmailTemplate> templates = [SELECT Id, Body, HtmlValue, TemplateType, subject FROM EmailTemplate WHERE Id = :EmailTemplateId LIMIT 1];
					if (templates != null && templates.size()>=1) {
						template = templates[0]; 
					}
				}
				if (template != null) {
					//TODO handle merge fields
					//use plain body text from template
					
					//as merge fields are not permitted I have added the report name to the subject
					//'Lead Status' run at 23/11/2011 10:29
					mail.setSubject(template.subject + ' - ' + reportName + ' run at ' + datetime.now().format('dd/MM/yyyy HH:mm'));
					mail.setPlainTextBody(template.Body);
					
					//if the template has na HTML value then we will use it
					//either way the report scapping is appended to the template body
					if (template.HtmlValue != null) {
						mail.setHtmlBody(template.HtmlValue + '<br /><br /><br />' + reportHTML);
					} else {
						mail.setHtmlBody(template.Body + '<br /><br /><br />' + reportHTML);
					}
				} else {
					throw new customException('Unable to send emal: No Email Template Defined.');
				}
		
				System.debug('doExport...mail...' + mail);
				Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});   
				System.debug('doExport...mail sent');
			}
		
		} catch (Exception ex) {
			throw new customException('Unable to send emal.  Error: ' + ex.getMessage());
		}
	}
	
	public static Map<Id, Id> createJobHistories(List<Scheduled_Report_Export__c> scheduledEmails, String ExecutionMethod) {
   		//created job history records as a receipt of the transaction
   		
   		Id retId = null;
   		List<Scheduled_Report_Export_Job__c> jobs = new List<Scheduled_Report_Export_Job__c>();
   		Map<Id, Id> mapScheduledEmailIdJobId = new Map<Id, Id>();
   		
   		try {
   			for (Scheduled_Report_Export__c scheduledEmail : scheduledEmails) {
   				Scheduled_Report_Export_Job__c job = new Scheduled_Report_Export_Job__c();
	   			job.Scheduled_Report_Export__c = scheduledEmail.Id;
	   			job.Type__c = ExecutionMethod;
	   			job.Submitted_Date__c = Datetime.now();
	   			jobs.add(job);
   			}
   			
			Database.SaveResult[] insertSaveResults = Database.insert(jobs, false); //allow partial success
			
			Integer i = 0;	   		
	   		for (Database.SaveResult saveResult : insertSaveResults){
	   		   system.debug('createJobHistories...saveResult...' + saveResult);	
	   			
			   if (saveResult.isSuccess()) {
			   	    Id jobId = saveResult.getId();
			   	    Id schedEmailId = scheduledEmails.get(i).Id;
			   	    system.debug('createJobHistories...jobId...' + jobId);
			   	    system.debug('createJobHistories...schedEmailId...' + schedEmailId);
			   	   
			       mapScheduledEmailIdJobId.put(schedEmailId, saveResult.getId());
			   } else {
		   		   List<Database.Error> errs = saveResult.getErrors();
		   		   system.debug('createJobHistories...err...' + errs);
			   }
			   
			   i++;
			}
   		} catch (Exception ex) {
   			system.debug('createJobHistory...ex...' + ex);
   		}
   		
   		return mapScheduledEmailIdJobId;
   }
   
   public static void setJobHistorySuccess(Id jobId, Blob report, String reportName, Boolean saveResult, set<String> toAddresses) {   		
   		try {
   			String recipients = '';
   			for (String recipient : toAddresses) {
   				recipients+=recipient+'; ';
   			}
   			if (recipients.length()>0) recipients.substring(0, recipients.length()-1);
   			
	   		Scheduled_Report_Export_Job__c job = new Scheduled_Report_Export_Job__c(Id = jobId);
	   		job.Status__c = 'Success';
	   		job.Success__c = true;
	   		job.Completion_Date__c = Datetime.now();
	   		job.Email_Recipients__c = recipients;
	   		job.Results_Saved__c = saveResult;
	   		job.Results_Sent__c = (recipients != '');
	   		update job;
	   		
	   		if (saveResult) {
	   			Attachment att = new Attachment();
	   			att.ParentId = jobId;
	   			att.Body = report;
	   			att.ContentType = 'text/csv';
	   			att.Description = reportName;
	   			att.Name = reportName + '.csv';
	   			insert att;
	   		}
   		} catch (Exception ex) {
   			system.debug('setJobHistorySuccess...ex...' + ex);
   		}
   }
   
   public static void setJobHistoryFailure(Id jobId, String failReason) {
   		try {
	   		Scheduled_Report_Export_Job__c job = new Scheduled_Report_Export_Job__c(Id = jobId);
	   		job.Status__c = 'Failed';
	   		job.Failure_Reason__c = failReason;
	   		job.Completion_Date__c = Datetime.now();
	   		update job;
   		} catch (Exception ex) {
   			system.debug('setJobHistoryFailure...ex...' + ex);
   		}
   }
   
   public static void setName(List<Scheduled_Report_Export__c> schedReports) {
	   	//called by trigger this method sets the name of the scheduled report to the name of the report
	   	//could be extended to include schedule infp e.g. [ReportName] + 'Daily @ 07:00'
	   	
	   	try {
			Set<Id> reportIds = new Set<Id>();
			for (Scheduled_Report_Export__c sched : schedReports) {
				if (sched.Report_Id__c!=null) {
					reportIds.add(sched.Report_Id__c); 
				}
			}
			Map<Id, Report> reportNameMap = new Map<Id, Report>([SELECT Id, Name FROM Report WHERE Id IN :reportIds]);
			Report report;	
			for (Scheduled_Report_Export__c sched : schedReports) {
				report = reportNameMap.get(sched.Report_Id__c);
				if (report!=null) {
					sched.Name = report.Name;
				}
			}
		} catch (Exception ex) {
			system.debug('setName...ex...' + ex);
			throw new customException('Unable to setName.  Error: ' + ex.getMessage());
		}
   }
   public static void commitRecipients(List<Scheduled_Report_Export__c> schedReports) {
	   	//on every save I look for values in the UncommittedRecipientUser__c field
	   	//this field is used like a map to store key/value pairs of userids and email addresses
	   	//this allows recipients to be added in UI but not committed until save
	   	//also allows recipients to be added prior to ID existing 
	   	
	   	try {
	   		System.debug('entering...commitRecipients');
	   		List<Scheduled_Report_Export_Recipient__c> recipientsToAdd = new List<Scheduled_Report_Export_Recipient__c>();
			Map<Id, String[]> mapRecepitentsToSchedule = new Map<Id, String[]>();
			
			
			for (Scheduled_Report_Export__c sched : schedReports) {
				if (sched.UncommittedRecipientUser__c!=null) {
					System.debug('commitRecipients...sched.UncommittedRecipientUser__c...' + sched.UncommittedRecipientUser__c);
					List<String> recs = sched.UncommittedRecipientUser__c.split(';');
					mapRecepitentsToSchedule.put(sched.Id, recs);
				}
			}
			

			for(Id schedId : mapRecepitentsToSchedule.keyset()) {
				List<String> recipients = mapRecepitentsToSchedule.get(schedId);
				System.debug('commitRecipients...recipients...' + recipients);
				System.debug('commitRecipients...recipients.size()...' + recipients.size());
				
				for (String recipient : recipients) {
					System.debug('commitRecipients...recipient...' + recipient);
					String[] recipientKey = recipient.split(',');
					System.debug('commitRecipients...recipientKey...' + recipientKey);
					System.debug('commitRecipients...recipientKey.size()...' + recipientKey.size());
					
					if (recipientKey!=null && recipientKey.size() == 2) {
						//we have a matching pair
						if (recipientKey[0]!='null') {
							//we have an Id
							System.debug('commitRecipients...recipientKey[0]...' + recipientKey[0]);
							System.debug('commitRecipients...recipientKey[1]...' + recipientKey[1]);
							
							Scheduled_Report_Export_Recipient__c recipientUser = new Scheduled_Report_Export_Recipient__c();
							recipientUser.Scheduled_Report_Export__c = schedId;
							recipientUser.Recipient__c = recipientKey[0];
							//ecipient.Custom_Email__c = recipientName;
							recipientUser.Name = recipientKey[1];
							recipientUser.UniqueId__c = String.valueOf(schedId).substring(0,15) + String.valueOf(recipientKey[0]).substring(0,15);
							recipientsToAdd.add(recipientUser);
						} else {
							System.debug('commitRecipients...recipientKey[1]...' + recipientKey[1]);
							//we have an email as id is null
							Scheduled_Report_Export_Recipient__c recipientEmail = new Scheduled_Report_Export_Recipient__c();
							recipientEmail.Scheduled_Report_Export__c = schedId;
							recipientEmail.Custom_Email__c = recipientKey[1];
							recipientEmail.Name = recipientKey[1];
							recipientEmail.UniqueId__c = String.valueOf(schedId).substring(0,15) + String.valueOf(recipientKey[1]);
							recipientsToAdd.add(recipientEmail);
						}
					}
				}
			}
				
				
			
			System.debug('commitRecipients...recipientsToAdd...' + recipientsToAdd);
			insert recipientsToAdd;
		} catch (Exception ex) {
			system.debug('commitRecipients...ex...' + ex);
			throw new customException('Unable to commit rRecipients.  Error: ' + ex.getMessage());
		}
   }
   
}