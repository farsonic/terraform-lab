
<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" indent="yes"/>
  <xsl:template match="node()|@*">
      <xsl:copy>
         <xsl:apply-templates select="node()|@*"/>
      </xsl:copy>
   </xsl:template>

  <xsl:template match="/domain/devices">
    <xsl:copy>
        <xsl:apply-templates select="node()|@*"/>
            <xsl:element name ="interface">
                <xsl:attribute name="type">direct</xsl:attribute>
                <xsl:element name="source">
                    <xsl:attribute name="dev">vlan.21</xsl:attribute>
                    <xsl:attribute name="mode">private</xsl:attribute>
	         </xsl:element>
	         <xsl:element name="model">
                    <xsl:attribute name="type">virtio</xsl:attribute>
                </xsl:element>
            </xsl:element>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>

