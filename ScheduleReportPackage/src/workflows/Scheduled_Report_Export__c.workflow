<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>Set_Uncommitted_Recipient_User_to_NULL</fullName>
        <field>UncommittedRecipientUser__c</field>
        <name>Set Uncommitted Recipient User to NULL</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Null</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>Clear Uncommitted Recipient User</fullName>
        <actions>
            <name>Set_Uncommitted_Recipient_User_to_NULL</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>Scheduled_Report_Export__c.UncommittedRecipientUser__c</field>
            <operation>notEqual</operation>
        </criteriaItems>
        <description>sets field to null so only new updates are applied</description>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
