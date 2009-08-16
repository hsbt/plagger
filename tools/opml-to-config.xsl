<?xml version="1.0" encoding="utf-8"?>
<x:stylesheet xmlns:x="http://www.w3.org/1999/XSL/Transform"
              version="1.0" >

 <x:output method="text" encoding="utf-8"/>

 <x:template match="/opml">
  <x:text>plugins:
  - module: Subscription::Config
    config:
      feed:
</x:text>
<x:apply-templates select="body//outline[not(*)]" />
 </x:template>

 <x:template match="outline">
  <x:text>        - url: </x:text><x:value-of select="@xmlUrl"/><x:text>
</x:text>
<x:if test="@htmlUrl">
 <x:text>          link: </x:text><x:value-of select="@htmlUrl"/><x:text>
</x:text>
</x:if>
<x:if test="@title">
 <x:text>          title: </x:text><x:apply-templates select="@title" mode="quote"/><x:text>
</x:text>
</x:if>
<x:if test="ancestor::outline[@text]">
 <x:text>          tag: </x:text><x:for-each select="parent::outline"><x:call-template name="tags"/></x:for-each><x:text>
</x:text>
</x:if>
 </x:template>

 <x:template match="*|@*" mode="quote">
  <x:choose>
   <x:when test="contains(.,'&quot;')"><x:text>'</x:text><x:value-of select="."/><x:text>'</x:text></x:when>
   <x:otherwise><x:text>"</x:text><x:value-of select="."/><x:text>"</x:text></x:otherwise>
  </x:choose>
 </x:template>

 <x:template name="tags">
  <x:variable name="this"><x:apply-templates select="@text" mode="quote"/></x:variable>
  <x:variable name="ret"><x:for-each select="parent::outline"><x:call-template name="tags"/></x:for-each> <x:value-of select="$this"/></x:variable>
  <x:value-of select="$ret"/>
 </x:template>

</x:stylesheet>
