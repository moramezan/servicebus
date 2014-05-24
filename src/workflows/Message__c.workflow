<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <rules>
        <fullName>OnMessageError</fullName>
        <active>true</active>
        <criteriaItems>
            <field>Message__c.Exception__c</field>
            <operation>notEqual</operation>
        </criteriaItems>
        <description>Use this hook to react to messages that encountered errors during processing. For example, you could send an email to the EDA Orchestrator.</description>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
