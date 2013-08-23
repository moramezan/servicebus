<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>IncrementSequence</fullName>
        <field>Sequence__c</field>
        <formula>BLANKVALUE(Chain__r.MaxChainStepSequence__c, 0) + 1</formula>
        <name>IncrementSequence</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>IncrementSequence</fullName>
        <actions>
            <name>IncrementSequence</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onCreateOnly</triggerType>
    </rules>
</Workflow>
