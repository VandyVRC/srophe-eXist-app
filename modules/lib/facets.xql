xquery version "3.1";

module namespace sf = "http://srophe.org/srophe/facets";
import module namespace functx="http://www.functx.com";
import module namespace config="http://srophe.org/srophe/config" at "../config.xqm";

declare namespace srophe="https://srophe.app";
declare namespace skos ="http://www.w3.org/2004/02/skos/core#";
declare namespace dcterms="http://purl.org/dc/terms/";
declare namespace facet="http://expath.org/ns/facet";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $sf:QUERY_OPTIONS := map {
    "leading-wildcard": "yes",
    "filter-rewrite": "yes"
};

(: Add sort fields to browse and search options. Used for sorting, add sort fields and functions, add sort function:)
declare variable $sf:sortFields := map { "fields": ("title", "author") };

(: ~ 
 : Build indexes for fields and facets as specified in facet-def.xml and search-config.xml files
 : Note: Investigate boost? 
:)
declare function sf:build-index(){
<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns="http://exist-db.org/collection-config/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:srophe="https://srophe.app">
        <lucene diacritics="no">
            <module uri="http://srophe.org/srophe/facets" prefix="sf" at="xmldb:exist:///{$config:app-root}/modules/lib/facets.xql"/>
            <text qname="tei:body">{
            let $facets :=     
                for $f in collection($config:app-root)//facet:facet-definition
                let $path := document-uri(root($f))
                group by $facet-grp := $f/@name
                return 
                    if($f[1]/facet:group-by/@function != '') then 
                       <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="sf:facet(descendant-or-self::tei:body, {concat("'",$path[1],"'")}, {concat("'",$facet-grp,"'")})"/>
                    else if($f[1]/facet:range) then
                       <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="sf:facet(descendant-or-self::tei:body, {concat("'",$path[1],"'")}, {concat("'",$facet-grp,"'")})"/>                
                    else 
                        <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="{replace($f[1]/facet:group-by/facet:sub-path/text(),"&#34;","'")}"/>      
            return 
                $facets
            }              
                <!-- Predetermined sort fields -->               
                <field name="title" expression="sf:field(descendant-or-self::tei:body,'title')"/>
                <field name="author" expression="sf:field(descendant-or-self::tei:body, 'author')"/>
            </text>
            <text qname="tei:TEI"/>
            <text qname="tei:fileDesc"/>
            <text qname="tei:biblStruct"/>
            <text qname="tei:publisher"/>
            <text qname="tei:pubPlace"/>
            <text qname="tei:div"/>
            <text qname="tei:author" boost="5.0"/>
            <text qname="tei:persName" boost="5.0"/>
            <text qname="tei:placeName" boost="5.0"/>
            <text qname="tei:title" boost="10.5"/>
            <text qname="tei:location"/>
            <text qname="tei:desc" boost="2.0"/>
            <text qname="tei:note"/>
            <text qname="tei:term"/>
        </lucene> 
        <range>
            <create qname="@type" type="xs:string"/>
            <create qname="@ana" type="xs:string"/>
            <create qname="@syriaca-tags" type="xs:string"/>
            <create qname="@when" type="xs:string"/>
            <create qname="@target" type="xs:string"/>
            <create qname="@who" type="xs:string"/>
            <create qname="@ref" type="xs:string"/>
            <create qname="@uri" type="xs:string"/>
            <create qname="@where" type="xs:string"/>
            <create qname="@active" type="xs:string"/>
            <create qname="@passive" type="xs:string"/>
            <create qname="@mutual" type="xs:string"/>
            <create qname="@name" type="xs:string"/>
            <create qname="@xml:lang" type="xs:string"/>
            <create qname="@level" type="xs:string"/>
            <create qname="@status" type="xs:string"/>
            <create qname="tei:idno" type="xs:string"/>
            <create qname="tei:title" type="xs:string"/>
            <create qname="tei:geo" type="xs:string"/>
            <create qname="tei:relation" type="xs:string"/>
            <create qname="tei:placeName" type="xs:string"/>
            <create qname="tei:author" type="xs:string"/>
            <create qname="tei:num" type="xs:string"/>
            <create qname="tei:trait" type="xs:string"/>
            <create qname="tei:relation">
                <field name="relation-ref" match="@ref" type="xs:string"/>
                <field name="relation-active" match="@active" type="xs:string"/>
                <field name="relation-passive" match="@passive" type="xs:string"/>
                <field name="relation-mutual" match="@mutual" type="xs:string"/>
              </create>
            <create qname="tei:trait">
                <field name="relation-type" match="@type" type="xs:string"/>
            </create>
        </range>
    </index>
</collection>
};

(:~ 
 : Update collection.xconf file for data application, can be called by post install script, or index.xql
 : Save collection to correct application subdirectory in /db/system/config
 : Trigger a re-index.
 : 
 : @note reindex does not seem to work... investigate 
 :)
declare function sf:update-index(){
    let $updateXconf := 
      try {
            let $configPath := concat('/db/system/config',replace($config:data-root,'/data',''))
            return xmldb:store($configPath, 'collection.xconf', sf:build-index())
        } catch * {('error: ',concat($err:code, ": ", $err:description))}
    return 
        if(starts-with($updateXconf,'error:')) then
            $updateXconf
        else xmldb:reindex($config:data-root)
};

(: Main facet function, for generic facets :)

(: Build facet path based on facet definition file. Used by collection.xconf to build facets at index time. 
 : @param $path - path to facet definition file, if empty assume root.
 : @param $name - name of facet in facet definition file. 
 :
 : TODO: test custom facets/fields
:)
declare function sf:facet($element as item()*, $path as xs:string, $name as xs:string){
    let $facet-definition :=  
        if(doc-available($path)) then
            doc($path)//facet:facet-definition[@name=$name]
        else () 
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    return 
        if(not(empty($facet-definition))) then  
            if($facet-definition/facet:group-by/@function != '') then 
              try { 
                    util:eval(concat('sf:facet-',string($facet-definition/facet:group-by/@function),'($element,$facet-definition, $name)'))
                } catch * {concat($err:code, ": ", $err:description)}
            else util:eval(concat('$element/',$xpath))
        else ()
};

(: For sort fields, or fields not defined in search-config.xml :)
declare function sf:field($element as item()*, $name as xs:string){
    try { 
        util:eval(concat('sf:field-',$name,'($element,$name)'))
    } catch * {concat($err:code, ": ", $err:description)}
};



(:~ 
 : Build fields path based on search-config.xml file. Used by collection.xconf to build facets at index time. 
 : @param $path - path to facet definition file, if empty assume root.
 : @param $name - name of facet in facet definition file. 
 : 
 : @note not currently implemented
:)
declare function sf:field($element as item()*, $path as xs:string, $name as xs:string){
    let $field-definition :=  
        if(doc-available($path)) then
            doc($path)//*:field[@name=$name]
        else () 
    let $xpath := $field-definition/*:expression/text()    
    return 
        if(not(empty($field-definition))) then  
            if($field-definition/@function != '') then 
                try { 
                    util:eval(concat('sf:field-',string($field-definition/@function),'($element,$field-definition, $name)'))
                } catch * {concat($err:code, ": ", $err:description)}
            else util:eval(concat('$element/',$xpath)) 
        else ()  
};


(: Custom search fields :)
(: Could be just shortened to  tokenize(util:eval(concat('$element/',$xpath)),' ')  do not need to group for Lucene facets i think?:)
declare function sf:facet-group-by-array($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    return tokenize(util:eval(concat('$element/',$xpath)),' ') 
};
(: Fit values into a specified range 
example: 
    <range type="xs:year">
        <bucket lt="0001" name="BC dates" order="22"/>
        <bucket gt="1600-01-01" lt="1700-01-01" name="1600-1700" order="5"/>
        <bucket gt="1700-01-01" lt="1800-01-01" name="1700-1800" order="4"/>
        <bucket gt="1800-01-01" lt="1900-01-01" name="1800-1900" order="3"/>
        <bucket gt="1900-01-01" lt="2000-01-01" name="1900-2000" order="2"/>
        <bucket gt="2000-01-01" name="2000 +" order="1"/>
    </range>
:)
declare function sf:facet-range($element as item()*, $facet-definition as item(), $name as xs:string){
    let $range := $facet-definition/facet:range 
    for $r in $range/facet:bucket
    let $path := if($r/@lt and $r/@lt != '' and $r/@gt and $r/@gt != '') then
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[. >= "', sf:type($r/@gt, $range/@type),'" and . <= "',sf:type($r/@lt, $range/@type),'"]')
                 else if($r/@lt and $r/@lt != '' and (not($r/@gt) or $r/@gt ='')) then 
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[. <= "',sf:type($r/@lt, $range/@type),'"]')
                 else if($r/@gt and $r/@gt != '' and (not($r/@lt) or $r/@lt ='')) then 
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[. >= "', sf:type($r/@gt, $range/@type),'"]')
                 else if($r/@eq) then
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[', $r/@eq ,']')
                 else ()
    let $f := util:eval($path)
    return if($f) then $r/@name else()
    
};

(: Title field :)
declare function sf:field-title($element as item()*, $name as xs:string){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        sf:build-sort-string($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:title)
    else if($element/ancestor-or-self::tei:TEI/descendant::tei:term[@xml:lang="zh-latn-pinyin"]) then 
        sf:build-sort-string($element/ancestor-or-self::tei:TEI/descendant::tei:term[@xml:lang="zh-latn-pinyin"][1])
    else sf:build-sort-string($element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt[1]/tei:title[1])
};

(: Title field :)
declare function sf:facet-title($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:title
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:title
};

(: Author field :)
declare function sf:field-author($element as item()*, $name as xs:string){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author | $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/descendant::tei:author[1]
};

(: Author field :)
declare function sf:facet-authors($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author | $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/descendant::tei:author
};

declare function sf:facet-biblAuthors($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author | $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/descendant::tei:author
};

(: Syriaca.org special facet :)
declare function sf:facet-type($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant-or-self::tei:place/@type) then
        lower-case($element/descendant-or-self::tei:place/@type)    
    else if($element/descendant-or-self::tei:person/@ana) then
        tokenize(lower-case($element/descendant-or-self::tei:person/@ana),' ')
    else ()
};

declare function sf:field-type($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant-or-self::tei:place/@type) then
        lower-case($element/descendant-or-self::tei:place/@type)    
    else if($element/descendant-or-self::tei:person/@ana) then
        tokenize(lower-case($element/descendant-or-self::tei:person/@ana),' ')
    else ()
};

declare function sf:field-idno($element as item()*, $facet-definition as item(), $name as xs:string){
    $element/descendant-or-self::tei:idno[@type='URI'][starts-with(.,$config:base-uri)]    
};

declare function sf:field-uri($element as item()*, $facet-definition as item(), $name as xs:string){
    $element/descendant-or-self::tei:idno[@type='URI'][starts-with(.,$config:base-uri)]    
};

declare function sf:facet-controlled-labels($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text() 
    return util:eval(concat('$element/',$xpath))
};

(: Display, output functions  :)
declare function sf:display($result as item()*, $facet-definition as item()*) {
    let $facet-definitions := 
        if($facet-definition/self::facet:facet-definition) then 'definition' 
        else $facet-definition/facet:facets/facet:facet-definition
    for $facet in $facet-definitions
    let $name := string($facet/@name)
    let $count := if(request:get-parameter(concat('all-',$name), '') = 'on' ) then () else string($facet/facet:max-values/@show)
    let $f := ft:facets($result, $name, $count)
    return 
        if (map:size($f) > 0) then
            <span class="facet-grp">
                <span class="facet-title">{string($facet/@label)}</span>
                <span class="facet-list">
                {array:for-each(sf:sort($f,$facet-definition/facet:order-by/text(),$facet-definition/facet:order-by/@direction), function($entry) {
                    map:for-each($entry, function($label, $freq) {
                        let $param-name := concat('facet-',$name)
                        let $facet-param := concat($param-name,'=',$label)
                        let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                        let $url-params := 
                            if($active) then replace(replace(replace(request:get-query-string(),encode-for-uri($label),''),concat($param-name,'='),''),'&amp;&amp;','&amp;')
                            else if(request:get-parameter('start', '')) then '&amp;start=1'
                            else concat($facet-param,'&amp;',request:get-query-string())
                        let $facetLabel := 
                            if(starts-with($label, $config:base-uri)) then 
                                collection($config:data-root)//tei:idno[. = concat($label,'/tei')]/ancestor::tei:TEI/descendant::tei:title[1]/text()
                            else $label
                        return
                            <a href="?{$url-params}" class="facet-label btn btn-default {$active}">
                            {if($active) then (<span class="glyphicon glyphicon-remove facet-remove"></span>)else ()}
                            {$facetLabel} <span class="count"> ({$freq})</span> </a>
                    })
                })}
                {if(map:size($f) = xs:integer($count)) then 
                    <a href="?{request:get-query-string()}&amp;all-{$name}=on" class="facet-label btn btn-info"> View All </a>
                 else ()}
                </span>
            </span>
        else () 
};

(:Architectura Sinica specific function (for now) :)
declare function sf:nested-display($result as item()*, $facet-definition as item()*) {
    let $facet-definitions := $facet-definition/descendant-or-self::facet:facet-definition[@name='searchCategory']
    let $subfacet-definitions := $facet-definition/descendant-or-self::facet:facet-definition[@name='keywordCategory']
    let $sf-name := string($subfacet-definitions/@name)
    let $sf-count := if(request:get-parameter(concat('all-',$sf-name), '') = 'on' ) then () else string($subfacet-definitions/facet:max-values/@show)
    let $sf := ft:facets($result, $sf-name, $sf-count)
    let $sf-display := 
            if (map:size($sf) > 0) then
                <span class="facet-grp">
                    <span class="facet-list">
                    {array:for-each(sf:sort($sf,(),()), function($entry) {
                        map:for-each($entry, function($label, $freq) {
                            let $param-name := concat('facet-',$sf-name)
                            let $facet-param := concat($param-name,'=',$label)
                            let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                            let $url-params := 
                                if($active) then replace(replace(replace(request:get-query-string(),encode-for-uri($label),''),concat($param-name,'='),''),'&amp;&amp;','&amp;') 
                                else concat($facet-param,'&amp;',request:get-query-string())
                            let $facetLabel := $label
                            return
                                <a href="?{$url-params}" class="facet-label btn btn-default {$active}">
                                {if($active) then (<span class="glyphicon glyphicon-remove facet-remove"></span>)else ()}
                                {$facetLabel} <span class="count"> ({$freq})</span> </a>
                        })
                    })}
                    {if(map:size($sf) = xs:integer($sf-count)) then 
                        <a href="?{request:get-query-string()}&amp;all-{$sf-name}=on" class="facet-label btn btn-info"> View All </a>
                    else ()}
                    </span>
                </span>
            else () 
    for $facet in $facet-definitions
    let $name := string($facet/@name)
    let $count := if(request:get-parameter(concat('all-',$name), '') = 'on' ) then () else string($facet/facet:max-values/@show)
    let $f := ft:facets($result, $name, $count)
    return 
            if (map:size($f) > 0) then
                <span class="facet-grp">
                    <span class="facet-title">{string($facet/@label)}</span>
                    <span class="facet-list">
                    {array:for-each(sf:sort($f,$facet-definition/facet:order-by/text(),$facet-definition/facet:order-by/@direction), function($entry) {
                        map:for-each($entry, function($label, $freq) {
                            let $param-name := concat('facet-',$name)
                            let $facet-param := concat($param-name,'=',$label)
                            let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                            let $url-params := 
                                if($active) then replace(replace(replace(request:get-query-string(),encode-for-uri($label),''),concat($param-name,'='),''),'&amp;&amp;','&amp;') 
                                else concat($facet-param,'&amp;',request:get-query-string())
                            let $facetLabel := $label
                            return
                                (<a href="?{$url-params}" class="facet-label btn btn-default {$active}">
                                {if($active) then (<span class="glyphicon glyphicon-remove facet-remove"></span>)else ()}
                                {$facetLabel} <span class="count"> ({$freq})</span> </a>,
                                if($label = 'architectural-feature' or $label = 'architectural feature') then 
                                    <span class="sub-facet">{$sf-display}</span>
                                else ()
                                )
                        })
                    })}
                    </span>
                </span>
            else () 
        (:
                                                <span class="facet-grp">
                                                    <span class="facet-title">{string($subfacet/@label)}</span>
                                                    <span class="facet-list">
                                                    
                                                    {if(map:size($f) = xs:integer($count)) then 
                                                        <a href="?{request:get-query-string()}&amp;all-{$name}=on" class="facet-label btn btn-info"> View All </a>
                                                     else ()}
                                                    </span>
                                                </span>
                                            else ()
    :)        
};

(:~ 
 : Add sort option to facets 
 : Work in progress, need to pass sort options from facet-definitions to sort function.
:)
declare function sf:sort($facets as map(*)?, $type, $direction) {
if($type = 'value') then
    array {
        if (exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $key ascending
            return
                map { $key: $value }
        else
            ()
    }
else 
 array {
        if (exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $value descending
            return
                map { $key: $value }
        else
            ()
    }
};

(:~
 : Build map for search query
 : Used by search functions
 :)
declare function sf:facet-query() {
    map:merge((
        $sf:QUERY_OPTIONS,
        $sf:sortFields,
        map {
            "facets":
                map:merge((
                    for $param in request:get-parameter-names()[starts-with(., 'facet-')]
                    let $dimension := substring-after($param, 'facet-')
                    return
                        map {
                            $dimension: request:get-parameter($param, ())
                        }
                ))
        }
    ))
};


(:~
 : Adds type casting when type is specified facet:facet:group-by/@type
 : @param $value of xpath
 : @param $type value of type attribute
:)
declare function sf:type($value as item()*, $type as xs:string?) as item()*{
    if($type != '') then  
        if($type = 'xs:string') then xs:string($value)
        else if($type = 'xs:string') then xs:string($value)
        else if($type = 'xs:decimal') then xs:decimal($value)
        else if($type = 'xs:integer') then xs:integer($value)
        else if($type = 'xs:long') then xs:long($value)
        else if($type = 'xs:int') then xs:int($value)
        else if($type = 'xs:short') then xs:short($value)
        else if($type = 'xs:byte') then xs:byte($value)
        else if($type = 'xs:float') then xs:float($value)
        else if($type = 'xs:double') then xs:double($value)
        else if($type = 'xs:dateTime') then xs:dateTime($value)
        else if($type = 'xs:date') then xs:date($value)
        else if($type = 'xs:gYearMonth') then xs:gYearMonth($value)        
        else if($type = 'xs:gYear') then xs:gYear($value)
        else if($type = 'xs:gMonthDay') then xs:gMonthDay($value)
        else if($type = 'xs:gMonth') then xs:gMonth($value)        
        else if($type = 'xs:gDay') then xs:gDay($value)
        else if($type = 'xs:duration') then xs:duration($value)        
        else if($type = 'xs:anyURI') then xs:anyURI($value)
        else if($type = 'xs:Name') then xs:Name($value)
        else $value
    else $value
};

(: Syriaca.org strip non sort characters :)
declare function sf:build-sort-string($titlestring as xs:string?) as xs:string* {
    replace(normalize-space($titlestring),'^\s+|^[‘|ʻ|ʿ|ʾ]|^[tT]he\s+|^[dD]e\s+|^[dD]e-|^[oO]n\s+[aA]\s+|^[oO]n\s+|^[aA]l-|^[aA]n\s|^[aA]\s+|^\d*\W|^[^\p{L}]','')
};

(: tcadrt functions :)
declare function sf:facet-searchCategory($element as item()*, $facet-definition as item(), $name as xs:string){
    (:for $key in $element/descendant::tei:relation[@ref='skos:broadMatch']/@passive
    return 
        array:for-each (array {$key}, function($k) {
            $element/descendant-or-self::tei:entryFree/@type
        })
       :)()
};

(: Does not work
declare function sf:facet-getNameFromURI($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text() 
    for $id in util:eval(concat('$element/',$xpath)) 
    let $title := collection($config:data-root)//tei:idno[. = concat(lower-case($id),'/tei')]/ancestor::tei:TEI/descendant::tei:title[1]
    return $title 
};
:)