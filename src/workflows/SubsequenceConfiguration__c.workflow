<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateSubsequenceConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(Sequence__c),
    &quot;This step must be configured&quot;,
    &quot;Fires sequence &apos;&quot; + Sequence__r.Name + &quot;&apos; in series then returns to this sequence&quot;
)</formula>
        <name>Update Subsequence Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnSubsequenceConfigurationUpsert</fullName>
        <actions>
            <name>UpdateSubsequenceConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
