<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE xsl:stylesheet [
<!ENTITY nbsp       "&#160;"   >
]>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" media-type="html" indent="yes" />

<xsl:template match="/">
    <p>What's new:
        <ul>
            <xsl:for-each select="log/logentry">
                <li><b>Rev. <xsl:value-of select="@revision" />:</b>&nbsp;<xsl:value-of select="msg" /></li>
            </xsl:for-each>
        </ul>
    </p>
</xsl:template>

</xsl:stylesheet>
