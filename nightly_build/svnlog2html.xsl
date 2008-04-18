<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE xsl:stylesheet [
<!ENTITY nbsp       "&#160;"   >
]>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" media-type="html" indent="yes" />

<xsl:template match="/">
    <p><span style="color: red; font-weight: bold;">IMPORTANT:</span> Should one of the nightly builds be unusable to you, please revert to an older build available from the nightly builds appcast RSS feed: <a href="http://messenger.sapo.pt/software_update/mac/nightly_builds/appcast_feed.xml">http://messenger.sapo.pt/software_update/mac/nightly_builds/appcast_feed.xml</a>. Please bookmark this URL for future reference.</p>
    <p>What's new:
        <ul>
            <xsl:for-each select="log/logentry">
                <li><b>Rev. <xsl:value-of select="@revision" /> (build <xsl:value-of select="@revision + 500" />):</b>&nbsp;<xsl:value-of select="msg" /></li>
            </xsl:for-each>
        </ul>
    </p>
	<p><a href="http://trac.softwarelivre.sapo.pt/sapo_msg_mac/timeline?daysback=30&amp;changeset=on&amp;update=Update">More Changes</a></p>
</xsl:template>

</xsl:stylesheet>
