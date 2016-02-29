xquery version "3.0";
(:~
 : Builds browse page for Syriac.org sub-collections 
 : Alphabetical English and Syriac Browse lists
 : Browse by type
 :
 : @see lib/geojson.xqm for map generation
 :)

module namespace bs="http://syriaca.org/bs";

import module namespace global="http://syriaca.org/global" at "lib/global.xqm";
import module namespace common="http://syriaca.org/common" at "search/common.xqm";
import module namespace facets="http://syriaca.org/facets" at "lib/facets.xqm";
import module namespace ev="http://syriaca.org/events" at "lib/events.xqm";
import module namespace rel="http://syriaca.org/related" at "lib/get-related.xqm";
import module namespace rec="http://syriaca.org/short-rec-view" at "short-rec-view.xqm";
import module namespace geo="http://syriaca.org/geojson" at "lib/geojson.xqm";
import module namespace templates="http://exist-db.org/xquery/templates";

declare namespace xslt="http://exist-db.org/xquery/transform";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace util="http://exist-db.org/xquery/util";

(:~ 
 : Parameters passed from the url
 : @param $bs:coll selects collection (persons/places ect) for browse.html 
 : @param $bs:type selects doc type filter eg: place@type person@ana
 : @param $bs:view selects language for browse display
 : @param $bs:sort passes browse by letter for alphabetical browse lists
 :)
declare variable $bs:coll {request:get-parameter('coll', '')};
declare variable $bs:type {request:get-parameter('type', '')}; 
declare variable $bs:view {request:get-parameter('view', '')};
declare variable $bs:sort {request:get-parameter('sort', '')};
declare variable $bs:date {request:get-parameter('date', '')};
declare variable $bs:fq {request:get-parameter('fq', '')};
declare variable $bs:title {request:get-parameter('title', '')};
declare variable $bs:start {request:get-parameter('start', 1) cast as xs:integer};
declare variable $bs:perpage {request:get-parameter('perpage', 25) cast as xs:integer};

declare function bs:spear-person($node as node(), $model as map(*)){
let $d := util:eval(concat('$model("browse-data")//tei:div[descendant::tei:persName]',facets:facet-filter()))
for $data in $d
group by $facet-grp := $data/descendant::tei:persName[1]/@ref
return $data[1]
};

declare function bs:spear-place($node as node(), $model as map(*)){
let $d := util:eval(concat('$model("browse-data")//tei:div[descendant::tei:placeName]',facets:facet-filter()))
for $data in $d
group by $facet-grp := $data/descendant::tei:placeName[1]/@ref
return $data[1]
};

declare function bs:spear-event($node as node(), $model as map(*)){
    util:eval(concat('$model("browse-data")//tei:div[descendant::tei:listEvent]',facets:facet-filter()))
};

declare function bs:narrow-by-type(){
    if($bs:type = 'persons') then '[tei:listPerson]'
    else if($bs:type = 'events') then '[tei:listEvent]'
    else if($bs:type = 'relations') then '[tei:listRelation]'
    else ()
};

declare function bs:narrow-by-title(){
concat("[ancestor::tei:TEI/descendant::tei:titleStmt/tei:title[@level='a'][1][. = '",$bs:title,"']]")
};

(:~ 
 : Build Facet groups
 : For browsing by element type 
:)
declare function bs:spear-facet-groups($nodes, $category){
    <li><a href="?view=sources&amp;type={$category}&amp;fq={$facets:fq}" class="facet-label"> {$category} factoids <span class="count">({count($nodes)})</span></a></li>
};

(:,facets:facet-filter() :)
declare function bs:narrow-spear($node as node(), $model as map(*)){
let $data :=
    if($bs:view = 'person') then 
        bs:spear-person($node, $model)
    else if($bs:view = 'place') then 
        $model("browse-data")//tei:placeName
    else if($bs:view = 'event') then 
        bs:spear-event($node, $model)
    else if($bs:view = 'keyword') then   
        bs:spear-event($node, $model)
    else if($bs:view = 'advanced') then 
        util:eval(concat('$model("browse-data")//tei:div',facets:facet-filter()))
    else util:eval(concat('$model("browse-data")//tei:div',facets:facet-filter(),bs:narrow-by-type()))
return $data
};

declare function bs:spear-results-panel($node as node(), $model as map(*)){
let $data := $model("browse-refine")
(:util:eval(concat('$model("browse-data")//tei:div',bs:narrow-by-type-spear(),facets:facet-filter())):)
return
 (
    if($bs:view = 'person' or $bs:view = 'place') then 'ABC Menu' else(),
    if($bs:view = 'relations') then 
        <div class="col-md-12">
            <h3>Explore SPEAR Relationships</h3>
            <iframe id="iframe" src="../modules/d3xquery/build-html.xqm" width="100%" height="700" scrolling="auto" frameborder="0" seamless="true"/>
        </div>
    else                 
        (
        <div class="col-md-3">
            {
                if($bs:view = 'advanced') then 
                    <div>
                        
                        {
                            let $facets := $data//tei:persName | $data//tei:placeName | $data//tei:event 
                            | $data/ancestor::tei:TEI/descendant::tei:title[@level='a'][parent::tei:titleStmt]
                            return facets:facets($facets)
                        }
                    </div>
                else
                    <div>
                        <h4>Narrow by Source Text</h4>
                        <span class="facets applied">
                            {
                                if($facets:fq) then facets:selected-facet-display()
                                else ()            
                            }
                        </span>
                        <ul class="nav nav-tabs nav-stacked" style="margin-left:-1em;">
                            <!-- BUILD into facets -->
                            <!--<li><a href="?filter=all" class="facet-label">All <span class="count">  ({count($model("browse-refine"))})</span></a></li>-->
                           {
                               <li>{facets:title($data)}</li>
                           }
                        </ul>
                        {
                        if($bs:view = 'keywords') then 
                           (<h4>Narrow by Keyword</h4>,
                            <ul class="nav nav-tabs nav-stacked" style="margin-left:-1em;">
                                {
                                   let $facet-nodes := $data
                                   let $facets := $facet-nodes//tei:event
                                   return 
                                   <li>{facets:keyword($facets)}</li>
                                }
                           </ul>)
                        else ()
                        }
                        {
                         if($bs:view = 'sources' or $bs:view = '') then 
                            (<h4>Narrow by Type</h4>,
                                if($bs:type != '') then 
                                    <span class="facets applied">
                                    <span class="facet" title="Remove {$bs:type}">
                                        <span class="label label-facet" title="{$bs:type}">{$bs:type} 
                                            <a href="?view=sources&amp;fq={$facets:fq}" class="facet icon"><span class="glyphicon glyphicon-remove" aria-hidden="true"></span></a>
                                        </span>
                                    </span>            
                                    </span>
                                else(),
                                <ul class="nav nav-tabs nav-stacked" style="margin-left:-1em;">
                                    {(
                                        bs:spear-facet-groups($data/tei:listPerson, 'persons'),
                                        bs:spear-facet-groups($data/tei:listEvent, 'events'), 
                                        bs:spear-facet-groups($data/tei:listRelation, 'relations') 
                                    )}
                                </ul>)
                            else ()
                        }
                    </div>
            }
              
        </div>,
         <div class="col-md-8">
            {
                if($bs:view = 'advanced') then
                    <div class="container">
                        <h4>Advanced Browse ({count($data)})</h4>
                            {bs:display-spear($data)}
                    </div>    
                else if($bs:view = 'sources' or $bs:view = '') then 
                        <div>
                            <h3>Browse Factoids by Source ({count($data)})</h3>
                            {
                                if($bs:fq != '' or $bs:type != '') then
                                        bs:display-spear($data) 
                                else 
                                    <h4>Select a Source </h4>
                            }
                        </div>
                else 
                    (
                    <h3>
                        {
                            if($bs:view = 'keywords') then concat('Browse Factoids by Keywords (',count($data),')')
                            else if($bs:view = 'persons') then concat('Persons Mentioned (',count($data),')')
                            else if($bs:view = 'places') then concat('Places Mentioned (',count($data),')')
                            else if($bs:view = 'events') then concat('Browse Events (',count($data),')')
                            else concat('Browse (',count($data),')')
                        }
                    </h3>,
                    bs:display-spear($data))
            }
        </div>
        )
    )
};

(: add paging 
<h3>{if($bs:view) then $bs:view else 'Factoids'} ({count($data)})</h3>
:)
declare function bs:display-spear($data){
<div>
    <div>
        {
            if($bs:view = 'events') then 
                (ev:build-timeline($data,'events'), ev:build-events-panel($data))
            else if($bs:view = 'persons') then 
                bs:spear-person($data)
            else if($bs:view = 'places') then 
                bs:spear-places($data)                
            else 
                for $d in $data
                return rec:display-recs-short-view($d,'')
        }
    </div>
</div>
};

declare function bs:display-recs-short-view($node,$lang){
  transform:transform($node, doc($global:app-root || '/resources/xsl/rec-short-view.xsl'), 
    <parameters>
        <param name="data-root" value="{$global:data-root}"/>
        <param name="app-root" value="{$global:app-root}"/>
        <param name="nav-base" value="{$global:nav-base}"/>
        <param name="base-uri" value="{$global:base-uri}"/>
        <param name="lang" value="en"/>
        <param name="spear" value="true"/>
    </parameters>
    )
};

declare function bs:spear-person($nodes){
for $d in $nodes
let $id := string($d/descendant::tei:persName[1]/@ref)
let $connical := collection($global:data-root)//tei:idno[. = $id]
let $name := if($connical) then $connical/ancestor::tei:body/descendant::*[@syriaca-tags="#syriaca-headword"][@xml:lang='en'][1]
                else if($d/text()) then $d/text()[1]
                else tokenize($id,'/')[last()]
order by $name
return 
    if($connical) then 
            bs:display-recs-short-view($connical/ancestor::tei:TEI,'')
    else
     <div class="results-list">
        <span class="srp-label">Name: {$name} </span>
        <span class="results-list-desc uri"><span class="srp-label">URI:</span> {$id}</span>
        <span class="results-list-desc uri"><span class="srp-label">SPEAR:</span> <a href="factoid.html?id={$id}"> http://syriaca.org/spear/factoid.html?id={$id}</a></span>
    </div>
};

declare function bs:spear-places($nodes){
for $d in $nodes
let $id := string($d/descendant::tei:placeName[1]/@ref)
let $connical := collection($global:data-root)//tei:idno[. = $id]
let $name := if($connical) then $connical/ancestor::tei:body/descendant::*[@syriaca-tags="#syriaca-headword"][@xml:lang='en'][1]
             else if(empty($d/descendant::tei:placeName[1])) then tokenize($id,'/')[last()]
             else normalize-space($d/descendant::tei:placeName[1]/text())
             (:else if($d/text()) then $d/text()
             else if($d/child::*/text()) then $d/child::*[1]/text()
             else tokenize($id,'/')[last()]:)
(:where $d/descendant::tei:placeName/@ref:)
order by $name
return 
    if($connical) then 
            bs:display-recs-short-view($connical/ancestor::tei:TEI,'')
    else
     <div class="results-list">
        <span class="srp-label">Name: {$name} </span>
        <span class="results-list-desc uri"><span class="srp-label">URI:</span> {$id}</span>
        <span class="results-list-desc uri"><span class="srp-label">SPEAR:</span> <a href="factoid.html?id={$id}"> http://syriaca.org/spear/factoid.html?id={$id}</a></span>
    </div>
};




(:~
 : Browse Tabs - SPEAR
:)
declare function bs:build-tabs-spear($node, $model){    
    (<li>{if(not($bs:view)) then 
                attribute class {'active'} 
          else if($bs:view = 'sources') then 
                attribute class {'active'}
          else '' }<a href="browse.html?view=sources">Sources</a>
    </li>,
    <li>{if($bs:view = 'persons') then 
                attribute class {'active'} 
        else '' }<a href="browse.html?view=persons">Persons</a>
    </li>,
    <li>{if($bs:view = 'events') then 
                attribute class {'active'}
             else '' }<a href="browse.html?view=events">Events</a>
    </li>,
    <li>{
             if($bs:view = 'relations') then 
                attribute class {'active'} 
             else '' }<a href="browse.html?view=relations">Relations</a>
    </li>,
    <li>{if($bs:view = 'places') then 
                attribute class {'active'} 
             else '' }<a href="browse.html?view=places">Places</a>
    </li>,
    <li>{if($bs:view = 'keywords') then 
                attribute class {'active'}
             else '' }<a href="browse.html?view=keywords">Keywords</a>
    </li>,
    <li>{if($bs:view = 'advanced') then 
                attribute class {'active'}
             else '' }<a href="browse.html?view=advanced">Advanced Browse</a>
    </li>)
};