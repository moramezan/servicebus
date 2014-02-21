<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateDebouncerConfigurationName</fullName>
        <field>Name</field>
        <formula>&quot;Throttles messages to a maximum of one every &quot; + TEXT(MinimumHoursBetween__c) + IF(MinimumHoursBetween__c == 1, &quot; hour&quot;, &quot; hours&quot;) + &quot;.&quot;</formula>
        <name>Update Debouncer Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnDebouncerConfigurationUpsert</fullName>
        <actions>
            <name>UpdateDebouncerConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
