<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>UpdateScrapeConfigurationName</fullName>
        <field>Name</field>
        <formula>IF(
    ISBLANK(Endpoint__c),
    LEFT(&quot;This step must be configured&quot;, 80),
    LEFT(&quot;Downloads &quot; + Endpoint__c, 80)
)</formula>
        <name>Update Scrape Configuration Name</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>OnScrapeConfigurationUpsert</fullName>
        <actions>
            <name>UpdateScrapeConfigurationName</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>true</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
