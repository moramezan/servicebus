<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateIsNewDataConfigurationName</fullName>
        <field>Name</field>
        <formula>&quot;Throttles messages to a maximum of one every &quot; + TEXT(MinimumHoursBetween__c) + IF(MinimumHoursBetween__c == 1, &quot; hour&quot;, &quot; hours&quot;)</formula>
        <name>Update IsNewData Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnIsNewDataConfigurationUpsert</fullName>
        <actions>
            <name>UpdateIsNewDataConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
