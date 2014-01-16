<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>ChainStepSequenceUpdate</fullName>
        <description>This sequence incrementer works for single inserts. Keep in mind that multiple 0-Sequence steps inserted in the same execution context will not increment separately.</description>
        <field>Sequence__c</field>
        <formula>Chain__r.ChainStepsCount__c + 1</formula>
        <name>ChainStepSequenceUpdate</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnChainStepInsert</fullName>
        <actions>
            <name>ChainStepSequenceUpdate</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>Sequence__c == 0</formula>
        <triggerType>onCreateOnly</triggerType>
    </rules>
</Workflow>
