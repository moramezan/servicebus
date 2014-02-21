<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateJumpConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(Chain__c),
    &quot;This step must be configured.&quot;,
    &quot;Swallows the message and diverts it to chain &apos;&quot; + Chain__r.Name + &quot;&apos;.&quot;
)</formula>
        <name>Update Jump Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnJumpConfigurationUpsert</fullName>
        <actions>
            <name>UpdateJumpConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
