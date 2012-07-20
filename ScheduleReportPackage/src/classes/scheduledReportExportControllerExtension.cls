public with sharing class scheduledReportExportControllerExtension {
	public class customException extends Exception{}
	
	public Scheduled_Report_Export__c schReport { get; set; }
	private String context;
	public String recipientName { get; set; }
	public String recipientId { get; set; }
	public String recipientRemoveId { get; set; }
	
	List<Scheduled_Report_Export_Recipient__c> tempRecipients = new List<Scheduled_Report_Export_Recipient__c>();
	List<Scheduled_Report_Export_Recipient__c> savedRecipients = new List<Scheduled_Report_Export_Recipient__c>();
    
    public scheduledReportExportControllerExtension(ApexPages.StandardController stdController) {
        schReport = (Scheduled_Report_Export__c)stdController.getRecord();
        setContext();
        
        if (context.equals('New')) {
        	schReport.OwnerId = UserInfo.getUserId();
        }
        
        schReport.UncommittedRecipientUser__c='';
        getSavedRecipients();
    }
    
    public String getContext() {
    	return context;
    }
    public void setContext() {
    	//use the context for some UI alterations
    	try {
	    	String cloneParam = ApexPages.currentPage().getParameters().get('clone');

	    	if (schReport.Id == null && (cloneParam != null && cloneParam.equals('1'))) {
	    		context = 'Clone';
	    	} else if (schReport.Id == null) {
	    		context = 'New';
	    	} else {
	    		context = 'Edit';
	    	}
    	} catch (Exception ex) {
    		system.debug('setContext...ex...' + ex);
    	}
    }
    
    public PageReference startExportReport() {
    	SingleReportExport.exportReport(schReport.Id);
    	return null;
    }
    
    public Report getReport() {
    	//returns details of the single report
    	System.debug('getReport...schReport.Report_Id__c...' + schReport.Report_Id__c);
    	
    	 List<Report> reports = [SELECT Id, Name, Description, LastRunDate FROM Report WHERE Id = :schReport.Report_Id__c LIMIT 1];
    	 if (reports != null && reports.size()>0) {
    	 	return reports[0];
    	 } else {
    	 	return null;
    	 }
    }
    
    public void setName() {
    	Report report = getReport();
    	if (report != null) schReport.Name = report.Name;
    }
    
    public List<SelectOption> getReportSelectList() {
    	//returns a list of Reports as SelectOptions - limited to 500
    	
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('', '-- Select Report --',true));        

        List<Report> reports = [SELECT Id, Name FROM Report LIMIT 500];
        for (Report report : reports) {
            options.add(new SelectOption(report.Id, report.Name));
        }
        return options;
   }
   
   public List<SelectOption> getEmailTemplateSelectList() {
   		//returns a list of email templates as SelectOptions and seperates them by folder headings - limited to 500
   	
   		List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('', '-- Select Template --',true));        
		
		//returns all tmeplates in folders
        List<EmailTemplate> templates = [SELECT Id, Name,FolderId 
        								 FROM EmailTemplate 
        								 WHERE FolderId != null
        								 ORDER BY FolderId, Name
        								 LIMIT 500];    
        								 
	    Set<Id> folderIds = new Set<Id>();
	    for (EmailTemplate template : templates) {
	    	folderIds.add(template.FolderId);	
	    }   
	    Map<Id, Folder> folderById = new Map<Id, Folder>([SELECT Id, Name FROM Folder WHERE Id IN :folderIds]);
	    
        String prevFolderId = '';		
        Folder currentFolder;					 
        for (EmailTemplate template : templates) {
        	system.debug('getEmailTemplateSelectList...template...' + template);
        	
        	if (template.FolderId != null && !prevFolderId.equals(template.FolderId)) {
        		currentFolder = folderById.get(template.FolderId);		
        		if (currentFolder != null) {
        			options.add(new SelectOption('', currentFolder.Name, true));
        		}
        	}
            options.add(new SelectOption(template.Id, template.Name));
            prevFolderId = template.FolderId;
        }
        return options;
   }
   
   private void getSavedRecipients() {
   		//sets the list of saved recipients
   		if (schReport.Id != null) {
			savedRecipients = [SELECT Id, Name, Custom_Email__c, Recipient__c, UniqueId__c, Recipient__r.Id, Recipient__r.Name, Recipient__r.Email
																	FROM Scheduled_Report_Export_Recipient__c
																	WHERE Scheduled_Report_Export__c = :schReport.Id ORDER BY CreatedDate Desc];

   		} 											
   }
   
   public List<Scheduled_Report_Export_Recipient__c> getRecipients() {
   		//merges the temp list and saved list of recipients
   		List<Scheduled_Report_Export_Recipient__c> recs = new List<Scheduled_Report_Export_Recipient__c>();
   		recs.addAll(tempRecipients);
   		recs.addAll(savedRecipients);
   		return recs;
   }
   
    public PageReference addRecipient(){
    	//adds a temporary recipients ot the list and updates a background field used by trigger to create recipients      
        try {
        	if (recipientId=='') recipientId = null;
        	system.debug('addRecipient...recipientId...' + recipientId);
        	system.debug('addRecipient...recipientName...' + recipientName);
        	
			Scheduled_Report_Export_Recipient__c recipient = new Scheduled_Report_Export_Recipient__c();
			recipient.Scheduled_Report_Export__c = schReport.Id;
			if (recipientId!=null) recipient.Recipient__c = recipientId;
			if (recipientId==null) recipient.Custom_Email__c = recipientName;
			recipient.Name = recipientName;
			tempRecipients.add(recipient);
			
			//UncommittedRecipientUser is a text fields that builds a map of recipients to be created in the after triggers
			schReport.UncommittedRecipientUser__c+=String.valueOf(recipient.Recipient__c) + ',' + recipient.Name + ';';
			
			recipientName = null;
			recipientId = null;
        } catch (Exception ex) {
        	system.debug('addRecipient...ex...' + ex);
        } 
        return null;
    }
    
    public PageReference removeRecipient(){
    	try {
    		system.debug('addRecipient...recipientRemoveId...' + recipientRemoveId);
    		schReport.UncommittedRecipientUser__c='';
    		
    		List<Scheduled_Report_Export_Recipient__c> newTempRecipients = new List<Scheduled_Report_Export_Recipient__c>();
    		List<Scheduled_Report_Export_Recipient__c> delRecipients = new List<Scheduled_Report_Export_Recipient__c>();
    		
    		//loop the temp recipients matching on email or userid
    		//builds new list skipping the match so its removed form the new list
    		for (Scheduled_Report_Export_Recipient__c rec : tempRecipients) {
    			system.debug('addRecipient...rec.Custom_Email__c...' + rec.Custom_Email__c);
    			system.debug('addRecipient...rec.Recipient__c...' + rec.Recipient__c);
    			system.debug('addRecipient...rec.Recipient__c...' + rec.Id);
    			system.debug('addRecipient...rec.UniqueId__c...' + rec.UniqueId__c);	
  
				if (rec.Custom_Email__c==recipientRemoveId) {
					//dont add to new list
				} else if (String.valueOf(rec.Recipient__c)==recipientRemoveId) {
					//dont add to new list
				} else {
					newTempRecipients.add(rec);
					schReport.UncommittedRecipientUser__c+=String.valueOf(rec.Recipient__c) + ',' + rec.Name + ';';
				}
    		}
    		for (Scheduled_Report_Export_Recipient__c rec : savedRecipients) {
    			system.debug('addRecipient...rec.Custom_Email__c...' + rec.Custom_Email__c);
    			system.debug('addRecipient...rec.Recipient__c...' + rec.Recipient__c);
    			system.debug('addRecipient...rec.Recipient__c...' + rec.Id);
    			system.debug('addRecipient...rec.UniqueId__c...' + rec.UniqueId__c);

				if (rec.Id==recipientRemoveId) {
					//adds the recipient to a list of recipients ot be deleted
					delRecipients.add(rec);
					system.debug('addRecipient...delRecipients...' + delRecipients);
				}
    		}
    		
    		if (delRecipients.size()>0) {
    			delete delRecipients;
    			getSavedRecipients();//get new list of recipients from database
    		}
	    	tempRecipients = newTempRecipients;
	    	recipientRemoveId = null;
    	} catch (Exception ex) {
        	system.debug('removeRecipient...ex...' + ex);
        }
        return null;
    }

   
}