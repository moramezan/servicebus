<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateBranchConfigurationName</fullName>
        <description>Generates a friendly description of the configured behaviour.</description>
        <field>Name</field>
        <formula>IF(
    ISBLANK(Sequence__c),
    LEFT(&quot;This step must be configured&quot;, 80),
    LEFT(&quot;Copies the message to sequence &apos;&quot; + Sequence__r.Name + &quot;&apos;&quot;, 80)
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
        <description>Generates a friendly description of the configured behaviour.</description>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
