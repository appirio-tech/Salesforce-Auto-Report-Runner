public with sharing class Properties {
	
	private static String getStringValue(String key) {
		String retVal;
		
		try {
			Properties__c prop = Properties__c.getValues(key);
			retVal = prop.Value__c;
		} catch (Exception ex) {
			System.debug('Properties...getValueString...' + key + '...ex...' + ex);
		}
		
		return retVal;
	}
	private static Boolean getBooleanValue(String key) {
		Boolean retVal;
		
		try {
			if (getStringValue(key).equals('true')) {
				retVal = true;
			} else if (getStringValue(key).equals('false')) {
				retVal = false;
			}
		} catch (Exception ex) {
			System.debug('Properties...getValueBoolean...' + key + '...ex...' + ex);
		}
		
		return retVal;
	}

	public static Boolean isComplianceEnabled { get { return getBooleanValue('ccComplianceEnabled'); }	}
	public static String getComplianceEmail { get { return getStringValue('ComplianceEmail'); }	}
	public static String getSalesforceDomain { get { return getStringValue('SalesforceDomain'); }	}
	public static String getPassword { get { return getStringValue('Password'); }	}
	public static String getUsername { get { return getStringValue('Username'); }	}
	
}