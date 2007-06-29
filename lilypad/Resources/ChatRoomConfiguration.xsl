<?xml version="1.0" encoding="UTF-8"?>

<!DOCTYPE xsl:stylesheet [
<!ENTITY nbsp       "&#160;"   >
]>

<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xdata="jabber:x:data">
<xsl:output method="html" media-type="html"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhml1-transitional.dtd"
    doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
    indent="yes"/>

<xsl:template match="/">
	<html>
	<head>
		<style type="text/css">
			label {
				font: 13px 'Lucida Grande';
				text-transform: capitalize;
			}
			input[type='text'] , input[type='password'] {
				font: 13px 'Lucida Grande';
			}
			option {
				text-transform: capitalize;
			}
		</style>
	</head>
	
	<body onselectstart="return false" style="overflow: hidden;">
		<form method="post">
			<table border="0" cellpadding="2">
				<xsl:for-each select="xdata:x/xdata:field[@type != 'hidden']">
					<tr>
						<td align="right">
							<xsl:choose>
								<xsl:when test="@type = 'boolean'">
									&nbsp;
								</xsl:when>
								
								<xsl:otherwise>
									<label><xsl:value-of select="@label"/>:</label>
								</xsl:otherwise>
							</xsl:choose>
						</td>
						
						<td>
							<xsl:choose>
								<xsl:when test="@type = 'boolean'">
									<input type="checkbox" value="1">
										<xsl:attribute name="id">
											<xsl:value-of select="@var"/>
										</xsl:attribute>
										<xsl:if test="xdata:value = '1'">
											<xsl:attribute name="checked" />
										</xsl:if>
									</input>
									<label>
										<xsl:attribute name="for">
											<xsl:value-of select="@var"/>
										</xsl:attribute>
										<xsl:value-of select="@label"/>
									</label>
								</xsl:when>
								
								<xsl:when test="@type = 'text-single'">
									<input type="text">
										<xsl:attribute name="id">
											<xsl:value-of select="@var"/>
										</xsl:attribute>
										<xsl:attribute name="value">
											<xsl:value-of select="xdata:value" />
										</xsl:attribute>
									</input>
								</xsl:when>
								<xsl:when test="@type = 'text-private'">
									<input type="password">
										<xsl:attribute name="id">
											<xsl:value-of select="@var"/>
										</xsl:attribute>
										<xsl:attribute name="value">
											<xsl:value-of select="xdata:value" />
										</xsl:attribute>
									</input>
								</xsl:when>
								
								<xsl:when test="@type = 'list-single'">
									<select>
										<xsl:attribute name="id">
											<xsl:value-of select="@var"/>
										</xsl:attribute>
										<xsl:for-each select="xdata:option">
											<option>
												<xsl:attribute name="value">
													<xsl:value-of select="xdata:value" />
												</xsl:attribute>
												<xsl:if test="xdata:value = ../xdata:value">
													<xsl:attribute name="selected" />
												</xsl:if>
												<xsl:value-of select="@label" />
											</option>
										</xsl:for-each>
									</select>
								</xsl:when>
								<xsl:otherwise>
									<xsl:value-of select="xdata:value"/>
								</xsl:otherwise>
							</xsl:choose>
						</td>
					</tr>
				</xsl:for-each>
			</table>
		</form>
    </body>
    </html>
</xsl:template>

</xsl:stylesheet>
