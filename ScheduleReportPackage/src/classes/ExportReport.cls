public with sharing class ExportReport {
	
	/*
	
	Credits:
	Progmatic Access to Salesforce.com Reports
	http://sfdc-heretic.warped-minds.com/2006/04/10/progmatic-access-to-salesforcecom-reports/
	
	HTTP Callout to Salesforce
	http://boards.developerforce.com/t5/Best-Practices-Discussion/Http-Callout-to-Salesforce/td-p/179143
	
	
	*/
	public class customException extends Exception{}
	
	String sfDomain = Properties.getSalesforceDomain;
	String un = Properties.getUsername;
	String pw = Properties.getPassword;
	
	//used to direct the flow and set values when unit testing
	public enum TestPath {REDIRECT, REDIRECT_ERROR, OK_CSV, OK_NONCSV, ERROR}
	
	private HTTPRequest buildWebService(String endPoint, String sid) {
		HttpRequest req = new HttpRequest();
	    req.setEndpoint(endPoint);
	    req.setMethod('GET');
	    //if session id is provided add to the cookie so the webservice is authenticated
	    if (sid!=null) req.setHeader('Cookie','sid='+sid);
	    return req;
	}
	private HTTPResponse invokeWebService(HttpRequest req, String encoding, TestPath path) {
		Http http = new Http();
		HTTPResponse res = new HTTPResponse();
		if ( !Test.isRunningTest() ) {
			res = http.send(req);
		} else {
			//TEST EXECUTION PATH
			if (path == null) path = TestPath.OK_CSV;
			
			if (path == TestPath.Redirect) {
				res.setStatus('Found');
				res.setStatusCode(302);
				res.setHeader('Location', 'https://na12.salesforce.com/secur/frontdoor.jsp?sid=123456789&apv=1');
			} else if (path == TestPath.REDIRECT_ERROR) {
				res.setStatus('Found');
				res.setStatusCode(302);
				//do not provide redirect location
			} else if (path == TestPath.OK_CSV) {
				res.setStatus('OK');
				res.setStatusCode(200);
				res.setBody('IT WORKS!');
				res.setHeader('Content-Type', encoding);
			} else if (path == TestPath.OK_NONCSV) {
				res.setStatus('OK');
				res.setStatusCode(200);
				res.setBody('');
				res.setHeader('Content-Type', 'text/html; charset=UTF-8');
			} else if (path == TestPath.ERROR) {
				res.setStatus('ERROR');
				res.setStatusCode(404);
			}
			
		}
	    return res;
	}
	
	public String handleRedirectRequest(String redirectURI) {
		return handleRedirectRequest(redirectURI, TestPath.Redirect);
	}
	public String handleRedirectRequest(String redirectURI, TestPath path) {
        system.debug('Entering...handleRedirectRequest...' + redirectURI);
        
        try {
            HttpRequest req = buildWebService(redirectURI, null);
            HTTPResponse res = invokeWebService(req, '', path);

            if (res.getStatusCode() == 302) {
                //after first login salesforce retruns a redirect we need ot handle this
                redirectURI = res.getHeader('Location');

                if (redirectURI != null) {
                    System.debug('handleRedirectRequest...redirectURI ...' + redirectURI );
                    String sid = redirectURI.substring(redirectURI.indexOf('sid=')+4, redirectURI.indexOf('&', redirectURI.indexOf('sid=')));
                    System.debug('handleRedirectRequest...sid...' + sid);
                    sid = EncodingUtil.urlDecode(sid, 'UTF-8');
                    System.debug('handleRedirectRequest...sidDecoded...' + sid);
                    return sid;
                } else {
                    throw new customException('Redirect during login with no redirect location');
                }   
            } else {
                throw new customException('Unhandled response from web service, Web Service Response: ' + res);
            }
        } catch (System.CalloutException callOutEx) {
            throw new customException('Unable to login via web service.  Error: ' + callOutEx.getMessage());
        } catch (Exception ex) {
            throw new customException('Unkown Error: ' + ex.getMessage());
        }
    }

   private String getSessionId() {
		//as these methods are called from scheduled classes and futures UserInfo.session is not available
		//as a workaround I do a login call using httprequest adns crape the session id
		
		if (sfDomain == null) {
			throw new customException('Salesoforce domain URL not defined in custom setting');
		}
		if (un == null || pw == null) {
			throw new customException('Login credentials not defined in custom setting');
		}
		//login to salesforce using web callout to scrape for the session id
		String authURL = sfDomain + '?un=' + un + '&pw=' + pw;
		String sid = handleRedirectRequest(authURL);
		
		return sid;
   }
   
   public blob getReportAsCSV(Id reportId, TestPath path) {
   		String sid = getSessionId();
   		
   		//url format to return an exported report in csv format
   		String uri = sfDomain + reportId + '?export=1&enc=UTF-8&xf=csv';
   		return Blob.valueOf(getReport(uri, 'text/csv; charset=UTF-8', sid, path));
   }
   public String getReportAsHTML(Id reportId, TestPath path) {
   		String sid = getSessionId();
   		
   		//url format to return report without headers
   		String uri = sfDomain + reportId + '?isdtp=nv';
   		String body = getReport(uri, 'text/html; charset=UTF-8', sid, path);
   		if (body.indexOf('<div class="bGeneratedReport') > 0) {
   			//return just the body of the report output
	   		body = body.substring(body.indexOf('<div class="bGeneratedReport'), body.indexOf('</form>'));
   		} else {
   			//having trouble with more obscure reports e.g. Lead Status 
   			body = '';
   		}
		system.debug('runReport...body...' + body);
		return body;
   }
   private String getReport(String uri, String encoding, String sid, TestPath path) {
   		try {
   			system.debug('runReport...sid...' + sid);
   			system.debug('runReport...uri...' + uri);
			
			HttpRequest req = buildWebService(uri, sid);
		    HTTPResponse res = invokeWebService(req, encoding, path);
		    
			if (res.getStatusCode() == 200) {
				String body = res.getBody();
				system.debug('runReport...body...' + body);
				
				//check that the encoding is correct - during testing a response of text/html when csv is expected means the authentication failed somewhere
				if (res.getHeader('Content-Type').equals(encoding)) {
					return body;
				} else {
					throw new customException('Unexpected content type returned: ' + res.getHeader('Content-Type'));
				}	
			} else {
				system.debug('runReport...res...' + res);
				throw new customException('Unhandled response from web service, Web Service Response: ' + res);
			}
		} catch (Exception ex) {
			throw new customException('Unkown Error: ' + ex.getMessage());
		}
   }

}