<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>StepPositionUpdate</fullName>
        <description>This position incrementer works for single inserts. Keep in mind that multiple 0-Position steps inserted in the same execution context will not increment separately.</description>
        <field>Position__c</field>
        <formula>Chain__r.StepsCount__c + 1</formula>
        <name>StepPositionUpdate</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnStepInsert</fullName>
        <actions>
            <name>StepPositionUpdate</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>Position__c == 0</formula>
        <triggerType>onCreateOnly</triggerType>
    </rules>
</Workflow>
