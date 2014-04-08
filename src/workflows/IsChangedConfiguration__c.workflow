<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateIsChangedConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(FieldName__c),
    LEFT(&quot;This step must be configured&quot;, 80),
    LEFT(&quot;Continues only if &apos;&quot; + FieldName__c + &quot;&apos; has changed&quot;, 80)
)</formula>
        <name>Update IsChanged Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnIsChangedConfigurationUpsert</fullName>
        <actions>
            <name>UpdateIsChangedConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
