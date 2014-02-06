<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateBranchConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(Chain__c),
    &quot;This step must be configured.&quot;,
    &quot;Fires chain &apos;&quot; + Chain__r.Name + &quot;&apos; in parallel with a cloned notification.&quot;
)</formula>
        <name>Update Branch Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnBranchConfigurationUpsert</fullName>
        <actions>
            <name>UpdateBranchConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
