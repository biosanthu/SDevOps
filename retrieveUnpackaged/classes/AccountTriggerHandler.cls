/*****************************************************************************************
    Name    : Account_BeforeUpdate_Trigger
    Desc    : This is to update Account country and language fields based on user country details
    Approach: Used Custom settings to store country information
    Author  : Praneel PIDIKITI (Atos Integration)
    Project : Rforce
******************************************************************************************/

public with sharing class AccountTriggerHandler {

    //Before update method start
    public static void onBeforeUpdate(list < Account > listAccount, boolean isInsert, Map < Id, Account > oldMap){
        User u = [Select Id, RecordDefaultCountry__c from User Where Id = : UserInfo.getUserId()];
        //The code id modifed on 31-03-2105 by sumanth to implement best practice 
        //Update account country and language
        if (TriggerAdministration.canTrigger('Account.UpdateCountryWithUser')) {
            Rforce_AccCountry_and_AccLanguage.updateAccCountryandLanguage(listAccount,u);
            }
            
        //Added this code by sumanth for sms feature
        RForce_AccMobilePhoneUpdate.UpdateMobile(listAccount);

        /* NOC 13-05-2016 : Added for 16.07: RCPMO US 2608 : setting StopCom origin and sub-origin */
        if (TriggerAdministration.canTrigger('Account.StopComOrigin')) 
        {
            System.debug('## TRV : processing StopCom before update');
            User usr = [SELECT FederationIdentifier, UserType__c, TECH_TechnicalAction__c FROM User WHERE Id = :UserInfo.getUserId()];
            
            for (Account acc : listAccount) 
            {
                Account oldAcc = oldMap.get(acc.Id);
                if (
                    ((acc.StopComFlag__c != null && !acc.StopComFlag__c.equals(oldAcc.StopComFlag__c)) || (acc.StopComFlag__c == null && oldAcc.StopComFlag__c != null) &&
                    (acc.StopComOrigin__c == null || (acc.StopComOrigin__c != null && acc.StopComOrigin__c.equals(oldAcc.StopComOrigin__c)))) && usr.TECH_TechnicalAction__c == false
                   )
                {
                    acc.StopComOrigin__c = usr.UserType__c;
                    if ('SFA'.equals(usr.UserType__c))
                    {
                        acc.StopComSubOrigin__c = usr.FederationIdentifier;
                    }
                    else
                    {
                        acc.StopComSubOrigin__c = null;
                    }
                }
            }
        }
	}
    //Before update method end


    //Before Insert method start
    public static void onBeforeInsert(list <Account> listAccount, boolean isInsert, Map <Id, Account> oldMap){
        User u = [Select Id, RecordDefaultCountry__c, Bypass_Trigger__c from User Where Id = : UserInfo.getUserId()];
       //The code id modifed on 31-03-2105 by sumanth to implement best practice 
       //Update account country and language
       if (TriggerAdministration.canTrigger('Account.UpdateCountryWithUser')) {
            Rforce_AccCountry_and_AccLanguage.updateAccCountryandLanguage(listAccount,u);
            }
        //Added this code by sumanth for sms feature
        RForce_AccMobilePhoneUpdate.UpdateMobile(listAccount);
		
		/* NOC 13-05-2016 : Added for 16.07: RCPMO US 2608 : setting StopCom origin and sub-origin */
        if (TriggerAdministration.canTrigger('Account.StopComOrigin')) 
        {
            System.debug('## TRV : processing StopCom before insert');
            User usr = [SELECT FederationIdentifier, UserType__c, TECH_TechnicalAction__c FROM User WHERE Id = :UserInfo.getUserId()];
            
            for (Account acc : listAccount) 
            {
                if(acc.StopComFlag__c != null && acc.StopComOrigin__c == null && usr.TECH_TechnicalAction__c == false)
                {
                    acc.StopComOrigin__c = usr.UserType__c;
                    if ('SFA'.equals(usr.UserType__c))
                    {
                        acc.StopComSubOrigin__c = usr.FederationIdentifier;
                    }
                    else
                    {
                        acc.StopComSubOrigin__c = null;
                    }
                }
            }
        }
    }
    //Before Insert method end


    //After Insert method start
    public static void onAfterInsert(list <Account> listAccount, boolean isInsert, Map <Id, Account> oldMap){
        //The code id modifed on 31-03-2105 by sumanth to implement best practice  
        //Update the case accountid from account created using create account functionality from web to case
        Rforce_AccountIdtoCase.updateAccountIdtoCase(listAccount);
        // Added to attach the account to the corresponding lead
		Set<String> setleadNames = new Set<String>();
		Map<String, Lead> mNameToLead = new Map<String, Lead>();
		for(Account a : listAccount){ 
			  if(a.Lead__c != null)
			  {
				  setleadNames.add(a.Lead__c);
			  }
		}
		for(Lead oLead: [SELECT Name, Account__c FROM Lead WHERE Name IN: setleadNames]) {
			  mNameToLead.put(oLead.Name, oLead);
		}
		for(Account a : listAccount){ 
			  if(a.Lead__c !=null && mNameToLead.containsKey(a.Lead__c)) { 
				  mNameToLead.get(a.Lead__c).Account__c = a.id; 
			  } 
		} 
		try{
			  update mNameToLead.values();  
		  }catch(Exception e){
		}            

    }

	public static void duplicateAccountVisibility(list<Account> listAccount){
		//get the contact related to the current user
		Id curUserContact = [SELECT ContactId FROM User WHERE Id = :Userinfo.getUserId()].contactId;
		system.debug('#### AccountTriggerHandler - duplicateAccountVisibility - current User : '+Userinfo.getUserName());
		if(String.isNotBlank(curUserContact)){
			//get the account related to the current user (through the contact)
			Id curUserAcc = [SELECT AccountId FROM Contact WHERE Id= :curUserContact].AccountId;
			
			if(String.isNotBlank(curUserAcc)){
				//get the user roles whith highest level related to the account of the current user 
				List<UserRole> listUsrRole = [SELECT Id, PortalAccountId, Name FROM UserRole WHERE PortalAccountId = :curUserAcc and PortalRole = 'Executive'];
				if(!listUsrRole.isEmpty()){
					//get the group to share the account to insert (duplicate account)
					List<Group> listGroup = [SELECT Id, RelatedId, DeveloperName FROM Group WHERE RelatedId = :listUsrRole[0].Id and Type = 'RoleAndSubordinates'];
					if(!listGroup.isEmpty()){
						List<AccountShare> shares = new List<AccountShare>();
						for (Account acc : listAccount) {
							AccountShare share = new AccountShare();
							share.AccountId = acc.Id;
							share.UserOrGroupId = listGroup[0].Id;
							share.AccountAccessLevel = 'Edit';
							share.OpportunityAccessLevel = 'None';
							shares.add(share);
						}
						insert shares;
					}
				}
			}
		}
	}
    //After Insert method end



    //After Insert method start
    public static void onAfterUpdate(list <Account> listAccount, boolean isInsert, Map <Id, Account> oldMap){
  /*
        String comagrmnt;
        set<id>  acclistyes = new set <id>();
        set<id>  acclistno = new set <id>();
        List<Account> accList = new List<Account>();
     //When all the global communication agreemente are No the communication agrement is made yes if all are no then it is made no
        for (Account acc : listAccount) {
            if ((acc.ComAgreemt__c == system.label.Acc_CommAgremt_Partial) && (acc.Address__pc == system.label.Acc_CommAgremt_Yes && acc.ProfPhone__pc == system.label.Acc_CommAgremt_Yes
                 && acc.PersPhone__pc == system.label.Acc_CommAgremt_Yes && acc.ProEmailAddress__pc == system.label.Acc_CommAgremt_Yes && acc.PersEmail__pc == system.label.Acc_CommAgremt_Yes
                 && acc.ProfMobiPhone__pc == system.label.Acc_CommAgremt_Yes && acc.PersMobiPhone__pc == system.label.Acc_CommAgremt_Yes && acc.SMS__pc == system.label.Acc_CommAgremt_Yes )) {
                acclistyes.add(acc.id);
            }else if ((acc.ComAgreemt__c == system.label.Acc_CommAgremt_Partial) && (acc.Address__pc == system.label.Acc_CommAgremt_No && acc.ProfPhone__pc == system.label.Acc_CommAgremt_No
                       && acc.PersPhone__pc == system.label.Acc_CommAgremt_No && acc.ProEmailAddress__pc == system.label.Acc_CommAgremt_No && acc.PersEmail__pc == system.label.Acc_CommAgremt_No
                       && acc.ProfMobiPhone__pc == system.label.Acc_CommAgremt_No && acc.PersMobiPhone__pc == system.label.Acc_CommAgremt_No && acc.SMS__pc == system.label.Acc_CommAgremt_No )) {
                acclistno.add(acc.id);
            }
        }
        for (Account a : [Select ComAgreemt__c from account where id IN : acclistyes]) {
            a.ComAgreemt__c = system.label.Acc_CommAgremt_Yes;
            accList.add(a);
        }
        for (Account a : [Select ComAgreemt__c from account where id IN : acclistno]) {
            a.ComAgreemt__c = system.label.Acc_CommAgremt_No;
            accList.add(a);
        }
        try{
            update accList;
        }catch(Exception e){
            system.debug(e);
        } 
*/           
        //Added by sumanth on 20/03/2015 for Intaile Paris
        Rforce_SpecialCustomerStatus.updatespecialcustomerstatus(listAccount);
    }
    //After Insert method end

   //Before Delete method start
    public static void onBeforeDelete(list <Account> listAccount,Map<Id,Account> oldmap){
        //The code id modifed on 31-03-2105 by sumanth to implement best practice
        //Delete all the entitlements when an account is deleted 
        Rforce_AccountDeletion_CLS.deleteentitlements(listAccount,oldmap);    

    } 

	/**
	* @description processes specific checks and trigger actions for a country.
	* @param listAccount 
	* @param oldmap 
	*/
	public static void countrySpecific(List <Account> listAccount, Map<Id,Account> oldmap){
		User usr = [SELECT UserType__c, RecordDefaultCountry__c FROM User WHERE Id = :UserInfo.getUserId()];
		System.debug('#### AccountTriggerHandler - countrySpecific - UserType__c:'+usr.UserType__c);
		if (usr.UserType__c == 'SFA'){
			Country_Info__c ci = Country_Info__c.getInstance(usr.RecordDefaultCountry__c);
			System.debug('#### AccountTriggerHandler - countrySpecific - country info:'+ci);
			if (ci != null && String.isNotEmpty(ci.SFA_CountrySpecific_TriggerHandler__c)){
				Type t =  Type.forName(ci.SFA_CountrySpecific_TriggerHandler__c);
				SFA_CountrySpecific_TriggerHandler_INT impl = (SFA_CountrySpecific_TriggerHandler_INT) t.newInstance();
				if (oldmap == null){
					impl.onBeforeInsertAccount(listAccount);
				}else{
					impl.onBeforeUpdateAccount(listAccount, oldmap);
				}
			}
		}
	}
}