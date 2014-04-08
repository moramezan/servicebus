<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateSubscribeConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(EventType__c),
    LEFT(&quot;This step must be configured&quot;, 80),
    LEFT(&quot;Listens for any message published to &apos;&quot; + EventType__r.Name + &quot;&apos;&quot;, 80)
)</formula>
        <name>Update Subscribe Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnSubscribeConfigurationUpsert</fullName>
        <actions>
            <name>UpdateSubscribeConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
