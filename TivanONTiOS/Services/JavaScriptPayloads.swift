import Foundation

enum JavaScriptPayloads {
    static func literal(_ value: String) -> String {
        let data = try! JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    static let loginState = #"""
    (function(){
      const text=((document.body&&document.body.innerText)||'').toLowerCase();
      const hasPass=[...document.querySelectorAll('input')].some(x =>
        (x.type||'').toLowerCase()==='password' &&
        (x.offsetWidth||x.offsetHeight||x.getClientRects().length)
      );
      const logged =
        !hasPass &&
        (
          /logout|wan|tr-?069|system information|device information|status/.test(text) ||
          /\/html\//i.test(location.href)
        );
      return JSON.stringify({logged:logged,url:location.href,title:document.title,hasPassword:hasPass});
    })();
    """#

    static func login(username: String, password: String) -> String {
        #"""
        (function(){
          const USER=\#(literal(username)), PASS=\#(literal(password));
          function visible(e){
            if(!e) return false;
            const s=getComputedStyle(e);
            return s.display!=='none' && s.visibility!=='hidden' &&
              (e.offsetWidth||e.offsetHeight||e.getClientRects().length);
          }
          function setv(e,v){
            const d=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value');
            if(d&&d.set)d.set.call(e,v);else e.value=v;
            for(const n of ['input','change','blur']) e.dispatchEvent(new Event(n,{bubbles:true}));
          }
          function scan(doc){
            const ins=[...doc.querySelectorAll('input')].filter(visible);
            const pass=ins.find(x=>(x.type||'').toLowerCase()==='password');
            if(!pass) return null;
            const user=ins.find(x=>{
              const z=((x.id||'')+' '+(x.name||'')+' '+(x.placeholder||'')).toLowerCase();
              return (x.type||'').toLowerCase()!=='password' && /user|account|name|login/.test(z);
            }) || ins.find(x=>(x.type||'').toLowerCase()!=='password');
            if(!user) return null;
            setv(user,USER); setv(pass,PASS);
            const els=[...doc.querySelectorAll('button,input[type=submit],input[type=button],a')].filter(visible);
            let btn=els.find(e=>{
              const z=((e.innerText||'')+' '+(e.value||'')+' '+(e.id||'')+' '+(e.name||'')).toLowerCase();
              return /login|log in|ورود|submit|ok/.test(z);
            }) || els[0];
            if(btn){
              btn.click();
              return {ok:true,method:'click',userId:user.id||user.name||'',passId:pass.id||pass.name||''};
            }
            if(pass.form){
              if(typeof pass.form.requestSubmit==='function') pass.form.requestSubmit();
              else pass.form.submit();
              return {ok:true,method:'form',userId:user.id||user.name||'',passId:pass.id||pass.name||''};
            }
            return {ok:false,error:'login button/form not found'};
          }
          let r=scan(document);
          if(!r){
            for(const f of document.querySelectorAll('iframe,frame')){
              try{
                r=scan(f.contentDocument);
                if(r)break;
              }catch(e){}
            }
          }
          return JSON.stringify({result:r,url:location.href,title:document.title});
        })();
        """#
    }

    static let clickApply = #"""
    (function(){
      const docs=[document];
      for(const f of document.querySelectorAll('iframe,frame')){
        try{ if(f.contentDocument) docs.push(f.contentDocument); }catch(e){}
      }
      const apply=docs.map(d=>d.getElementById('ButtonApply')).find(Boolean) ||
        docs.map(d=>d.getElementById('Apply')).find(Boolean) ||
        docs.flatMap(d=>[...d.querySelectorAll('button,input[type=button],input[type=submit],a')])
          .find(e=>/(apply|submit|save|ok|confirm)/i.test((e.innerText||'')+' '+(e.value||'')+' '+(e.id||'')));
      if(!apply) return JSON.stringify({ok:false,error:'Apply button not found'});
      apply.click();
      return JSON.stringify({ok:true,button:apply.id||apply.name||apply.value||apply.innerText||'apply'});
    })();
    """#

    static let enableLANPorts = #"""
    (async function(){
      const sleep=ms=>new Promise(r=>setTimeout(r,ms));
      function norm(s){return (s||'').replace(/\s+/g,' ').trim().toLowerCase();}
      function visible(e){
        if(!e)return false;
        const s=getComputedStyle(e);
        return s.display!=='none'&&s.visibility!=='hidden'&&(e.offsetWidth||e.offsetHeight||e.getClientRects().length);
      }
      function fire(e){for(const n of ['input','change','blur'])e.dispatchEvent(new Event(n,{bubbles:true}));}
      function setChecked(e){
        if(!e || e.disabled)return false;
        if(e.checked)return true;
        e.click(); e.checked=true; fire(e);
        return !!e.checked;
      }
      function textOf(e){return norm((e.innerText||'')+' '+(e.id||'')+' '+(e.name||'')+' '+(e.title||''));}
      const result={ok:false,ports:[],changed:0,alreadyEnabled:0,lockedEnabled:0,diagnostics:[]};
      const seen=new Set();

      for(let i=1;i<=8;i++){
        const id='cb_Lan'+i;
        const e=document.getElementById(id);
        if(!e)continue;
        const port='LAN'+i;
        if(!visible(e) && !e.checked)continue;
        if(e.checked){
          result.ports.push({port,implementation:'exact-checkbox',disabled:!!e.disabled});
          result.alreadyEnabled++;
          if(e.disabled)result.lockedEnabled++;
        } else if(setChecked(e)){
          result.ports.push({port,implementation:'exact-checkbox',disabled:false});
          result.changed++;
        }
        seen.add(port);
      }

      if(result.ports.length===0){
        const candidates=[...document.querySelectorAll('tr,li,fieldset,div')].filter(visible);
        for(const container of candidates){
          const t=textOf(container);
          const m=t.match(/(?:^|\s)(?:lan|eth|ethernet)\s*(?:port\s*)?([1-8])(?:\s|$)/i);
          if(!m || /ssid|wlan|wi-?fi|binding|bind/.test(t))continue;
          const port='LAN'+m[1];
          if(seen.has(port))continue;
          const checks=[...container.querySelectorAll('input[type=checkbox]')];
          const e=checks.find(x=>/enable|active|lan|eth|port|switch/.test(textOf(x))) || checks[0];
          if(!e)continue;
          if(e.checked){
            result.ports.push({port,implementation:'fallback-checkbox',disabled:!!e.disabled});
            result.alreadyEnabled++;
            if(e.disabled)result.lockedEnabled++;
          } else if(setChecked(e)){
            result.ports.push({port,implementation:'fallback-checkbox',disabled:false});
            result.changed++;
          }
          seen.add(port);
        }
      }

      if(result.ports.length===0){
        result.diagnostics=[...document.querySelectorAll('input,select,button')]
          .slice(0,80).map(e=>textOf(e));
        return JSON.stringify({...result,error:'No physical LAN controls found'});
      }
      if(result.changed===0){
        result.ok=true;
        return JSON.stringify(result);
      }
      const apply=document.getElementById('Apply') || document.getElementById('ButtonApply') ||
        [...document.querySelectorAll('button,input[type=button],input[type=submit]')]
          .find(e=>/apply|save|submit|ok/i.test((e.innerText||'')+' '+(e.value||'')+' '+(e.id||'')));
      if(!apply){
        return JSON.stringify({...result,error:'LAN Apply button not found'});
      }
      result.button={id:apply.id||'',value:apply.value||'',text:apply.innerText||''};
      apply.click();
      result.apply=true;
      result.ok=true;
      await sleep(300);
      return JSON.stringify(result);
    })();
    """#

    static func configureACS(_ configuration: BootstrapConfiguration) -> String {
        #"""
        (async function(){
          const ACS_URL=\#(literal(configuration.acsURL));
          const ACS_USER=\#(literal(configuration.acsUsername));
          const ACS_PASS=\#(literal(configuration.acsPassword));
          const INTERVAL=\#(literal(configuration.informInterval));
          const sleep=ms=>new Promise(r=>setTimeout(r,ms));
          function visible(e){
            if(!e) return false;
            const s=getComputedStyle(e);
            return s.display!=='none'&&s.visibility!=='hidden'&&(e.offsetWidth||e.offsetHeight||e.getClientRects().length);
          }
          function docs(root){
            const out=[root];
            for(const f of root.querySelectorAll('iframe,frame')){
              try{ if(f.contentDocument) out.push(...docs(f.contentDocument)); }catch(e){}
            }
            return out;
          }
          const allDocs=docs(document);
          function norm(s){return (s||'').replace(/\s+/g,' ').trim().toLowerCase();}
          function ctx(e){
            const row=e.closest('tr')||e.closest('li')||e.closest('fieldset')||e.parentElement;
            return norm((row&&row.innerText||'')+' '+(e.id||'')+' '+(e.name||'')+' '+(e.title||''));
          }
          function controls(sel){return allDocs.flatMap(d=>[...d.querySelectorAll(sel)]).filter(visible);}
          function fire(e){for(const n of ['input','change','blur']) e.dispatchEvent(new Event(n,{bubbles:true}));}
          function setv(e,v){
            if(!e) return false;
            const proto=e.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;
            const d=Object.getOwnPropertyDescriptor(proto,'value');
            if(d&&d.set)d.set.call(e,v);else e.value=v;
            fire(e); return true;
          }
          function check(e,v=true){if(!e)return false;if(e.checked!==v)e.click();e.checked=v;fire(e);return true;}
          function byExact(ids,names){
            for(const id of ids){
              const e=allDocs.map(d=>d.getElementById(id)).find(Boolean);
              if(e)return e;
            }
            for(const name of names){
              const e=allDocs.flatMap(d=>[...d.querySelectorAll('[name="'+name+'"]')]).find(Boolean);
              if(e)return e;
            }
            return null;
          }
          const inputs=controls('input,textarea');
          const result={ok:false,found:{},warnings:[]};
          const enable=byExact(['EnableCWMP'],['x.EnableCWMP']) ||
            controls('input[type=checkbox]').find(e=>/enable.*(tr-?069|tr069|cwmp)|(tr-?069|tr069|cwmp).*enable/.test(ctx(e)));
          if(enable){check(enable,true);result.found.enable=true;}
          const urlInput=byExact(['URL','ACSURL'],['x.URL','URL']) ||
            inputs.find(e=>/acs.*url|url.*acs|cwmp.*url|url/.test(ctx(e)));
          if(!urlInput) return JSON.stringify({...result,error:'ACS URL field not found'});
          setv(urlInput,ACS_URL);result.found.url=urlInput.id||urlInput.name||'field';
          const textInputs=inputs.filter(e=>!['password','checkbox','radio','button','submit','hidden'].includes((e.type||'').toLowerCase()));
          const acsUser=byExact(['Username','ACSUsername'],['x.Username','Username']) ||
            textInputs.find(e=>/acs.*user|user.*acs|cwmp.*user|username/.test(ctx(e)));
          if(!acsUser) return JSON.stringify({...result,error:'ACS username field not found'});
          setv(acsUser,ACS_USER);result.found.user=acsUser.id||acsUser.name||'field';
          const passInputs=controls('input[type=password]');
          const acsPass=byExact(['Password','ACSPassword'],['x.Password','Password']) ||
            passInputs.find(e=>/acs.*pass|pass.*acs|cwmp.*pass|password/.test(ctx(e)));
          if(!acsPass) return JSON.stringify({...result,error:'ACS password field not found'});
          setv(acsPass,ACS_PASS);result.found.pass=acsPass.id||acsPass.name||'field';

          const crUser=byExact(
            ['ConnectionRequestUsername','ConnectionReqUsername','CRUsername'],
            ['x.ConnectionRequestUsername','ConnectionRequestUsername']
          ) || textInputs.find(e=>{
            const c=ctx(e);
            return /connection.*request.*user|request.*user/.test(c);
          });
          if(!crUser){
            return JSON.stringify({...result,error:'Connection Request username field not found'});
          }
          setv(crUser,ACS_USER);
          result.found.connectionRequestUser=crUser.id||crUser.name||'field';

          const crPass=byExact(
            ['ConnectionRequestPassword','ConnectionReqPassword','CRPassword'],
            ['x.ConnectionRequestPassword','ConnectionRequestPassword']
          ) || passInputs.find(e=>{
            const c=ctx(e);
            return /connection.*request.*pass|request.*pass/.test(c);
          });
          if(!crPass){
            return JSON.stringify({...result,error:'Connection Request password field not found'});
          }
          setv(crPass,ACS_PASS);
          result.found.connectionRequestPass=crPass.id||crPass.name||'field';

          const periodic=byExact(['PeriodicInformEnable'],['x.PeriodicInformEnable']) ||
            controls('input[type=checkbox]').find(e=>/periodic.*inform|inform.*periodic/.test(ctx(e)));
          if(periodic){check(periodic,true);result.found.periodic=true;}
          const interval=byExact(['PeriodicInformInterval'],['x.PeriodicInformInterval']) ||
            inputs.find(e=>/inform.*interval|periodic.*interval|interval.*inform/.test(ctx(e)));
          if(!interval) return JSON.stringify({...result,error:'Inform Interval field not found'});
          setv(interval,INTERVAL);result.found.interval=interval.id||interval.name||'field';

          const wanSelect=controls('select').find(s=>/wan|interface|bound/.test(ctx(s)));
          if(wanSelect){
            const opts=[...wanSelect.options].filter(o=>String(o.value||'').trim()!=='' && !/select|choose/.test(norm(o.text)));
            const chosen=opts.find(o=>/800|tr-?069|tr069|pppoe/.test(norm(o.text+' '+o.value))) || opts[0];
            if(chosen){wanSelect.value=chosen.value;fire(wanSelect);result.found.wan=norm(chosen.text+' '+chosen.value);}
          }
          await sleep(250);
          const apply=byExact(['ButtonApply','Apply'],['ButtonApply']) ||
            controls('button,input[type=button],input[type=submit]').find(e=>/apply|submit|save|ok/i.test(ctx(e)));
          if(!apply)return JSON.stringify({...result,error:'ACS Apply button not found'});
          result.ok=true;
          result.apply={id:apply.id||'',name:apply.name||'',text:apply.innerText||apply.value||''};
          return JSON.stringify(result);
        })();
        """#
    }

    static func configureWAN(_ configuration: BootstrapConfiguration) -> String {
        #"""
        (async function(){
          const USER=\#(literal(configuration.pppoeUsername));
          const PASS=\#(literal(configuration.pppoePassword));
          const VLAN=\#(literal(configuration.vlanID));
          const sleep=ms=>new Promise(r=>setTimeout(r,ms));
          function visible(e){
            if(!e) return false;
            const s=getComputedStyle(e);
            return s.display!=='none'&&s.visibility!=='hidden'&&(e.offsetWidth||e.offsetHeight||e.getClientRects().length);
          }
          function docs(root){
            const out=[root];
            for(const f of root.querySelectorAll('iframe,frame')){
              try{ if(f.contentDocument) out.push(...docs(f.contentDocument)); }catch(e){}
            }
            return out;
          }
          const allDocs=docs(document);
          function norm(s){return (s||'').replace(/\s+/g,' ').trim().toLowerCase();}
          function ctx(e){
            const row=e.closest('tr')||e.closest('li')||e.closest('fieldset')||e.parentElement;
            return norm((row&&row.innerText||'')+' '+(e.id||'')+' '+(e.name||'')+' '+(e.title||'')+' '+(e.placeholder||''));
          }
          function controls(sel){return allDocs.flatMap(d=>[...d.querySelectorAll(sel)]).filter(visible);}
          function fire(e){for(const n of ['input','change','blur']) e.dispatchEvent(new Event(n,{bubbles:true}));}
          function setv(e,v){
            if(!e) return false;
            const proto=e.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;
            const d=Object.getOwnPropertyDescriptor(proto,'value');
            if(d&&d.set)d.set.call(e,v);else e.value=v;
            fire(e); return true;
          }
          function check(e,v=true){
            if(!e) return false;
            if(e.checked!==v){ e.click(); }
            e.checked=v; fire(e); return true;
          }
          function choose(select, patterns, prefer){
            if(!select) return null;
            const opts=[...select.options];
            let candidates=opts.filter(o=>patterns.some(p=>norm(o.text+' '+o.value).includes(p)));
            if(!candidates.length) return null;
            if(prefer){
              const p=candidates.find(o=>prefer.some(x=>norm(o.text+' '+o.value)===x)) ||
                candidates.find(o=>prefer.some(x=>norm(o.text+' '+o.value).includes(x)));
              if(p) candidates=[p];
            }
            const chosen=candidates[0];
            select.value=chosen.value; fire(select);
            return norm(chosen.text+' '+chosen.value);
          }
          function findInput(patterns, type){
            const list=controls('input,textarea').filter(e=>!type||((e.type||'').toLowerCase()===type));
            return list.find(e=>patterns.some(p=>ctx(e).includes(p)));
          }
          function findCheckbox(patterns){
            return controls('input[type=checkbox]').find(e=>patterns.some(p=>ctx(e).includes(p)));
          }
          function findButton(patterns){
            const list=controls('button,input[type=button],input[type=submit],a');
            return list.find(e=>patterns.some(p=>norm((e.innerText||'')+' '+(e.value||'')+' '+(e.id||'')+' '+ctx(e)).includes(p)));
          }
          const result={ok:false,selected:{},found:{},warnings:[]};
          const selects=controls('select');
          function optionSummary(){
            return selects.map(s=>({id:s.id||'',name:s.name||'',ctx:ctx(s).slice(0,160),
              options:[...s.options].slice(0,20).map(o=>({text:o.text,value:o.value,selected:o.selected}))})).slice(0,30);
          }
          function inputSummary(){
            return controls('input,textarea').map(e=>({id:e.id||'',name:e.name||'',type:e.type||'',ctx:ctx(e).slice(0,160)})).slice(0,80);
          }
          function ownText(e){
            if(!e)return '';
            const labels=[];
            if(e.id){
              for(const d of allDocs){
                try{
                  const l=d.querySelector('label[for="'+CSS.escape(e.id)+'"]');
                  if(l)labels.push(l.innerText||'');
                }catch(err){}
              }
            }
            if(e.closest('label'))labels.push(e.closest('label').innerText||'');
            const siblingText=[e.previousElementSibling,e.nextElementSibling].filter(Boolean).map(x=>x.innerText||'').join(' ');
            return norm(labels.join(' ')+' '+siblingText+' '+(e.id||'')+' '+(e.name||'')+' '+(e.value||''));
          }
          function activateControl(e){
            if(!e)return false;
            const t=(e.type||'').toLowerCase();
            if(t==='radio'||t==='checkbox'){
              if(!e.checked)e.click();
              fire(e);
              return !!e.checked;
            }
            e.click(); fire(e); return true;
          }
          function selectExactPPPoE(){
            const radios=controls('input[type=radio]');
            let ranked=radios.map(e=>{
              const own=ownText(e);
              let score=0;
              if(/(^|[^a-z])pppoe([^a-z]|$)/.test(own))score+=100;
              if(norm(e.value)==='pppoe')score+=180;
              if(/pppoe/.test(norm(e.id+' '+e.name)))score+=140;
              if(/ipoe/.test(own)&&!/pppoe/.test(norm(e.value+' '+e.id+' '+e.name)))score-=120;
              return {e,score,own};
            }).filter(x=>x.score>0).sort((a,b)=>b.score-a.score);
            if(ranked.length && activateControl(ranked[0].e)){
              return {kind:'radio',text:ranked[0].own};
            }
            const groups={};
            for(const e of radios){
              const k=e.name||'__noname__';
              (groups[k]||(groups[k]=[])).push(e);
            }
            for(const [name,items] of Object.entries(groups)){
              const groupText=norm(items.map(e=>ctx(e)+' '+ownText(e)).join(' '));
              if(!/encap|encapsulation|ipoe|pppoe/.test(groupText))continue;
              if(items.length>=2){
                const candidate=items.find(e=>!/^ipoe$/i.test(String(e.value||'')) &&
                  (norm(e.value)==='pppoe'||/pppoe/.test(ownText(e)))) || items.find(e=>!/ipoe/.test(ownText(e)));
                if(candidate && activateControl(candidate)){
                  return {kind:'radio-fallback',group:name,text:ownText(candidate)};
                }
              }
            }
            const select=controls('select').find(s=>[...s.options].some(o=>{
              const x=norm(o.text+' '+o.value);
              return x==='pppoe'||norm(o.value)==='pppoe'||x.includes('pppoe');
            }));
            if(select){
              const opts=[...select.options];
              const o=opts.find(o=>norm(o.text)==='pppoe'||norm(o.value)==='pppoe') ||
                opts.find(o=>norm(o.text+' '+o.value).includes('pppoe'));
              if(o){
                select.value=o.value; fire(select);
                return {kind:'select',text:norm(o.text+' '+o.value)};
              }
            }
            return null;
          }
          function clickChoice(patterns, requiredAll=false){
            const candidates=controls('input[type=radio],input[type=checkbox],button,a').map(e=>{
              let text=norm(ownText(e)+' '+ctx(e)+' '+(e.innerText||'')+' '+(e.value||''));
              let score=0;
              const hits=patterns.filter(p=>text.includes(p)).length;
              if(requiredAll && hits!==patterns.length) return null;
              if(!requiredAll && hits===0) return null;
              score+=hits*40;
              if((e.type||'').toLowerCase()==='radio') score+=20;
              if(text===patterns.join(' ')) score+=60;
              return {e,score,text};
            }).filter(Boolean).sort((a,b)=>b.score-a.score);
            if(!candidates.length) return null;
            const c=candidates[0];
            activateControl(c.e);
            return c.text.slice(0,160);
          }

          let routeSel=controls('select').find(s=>{
            const opts=[...s.options].map(o=>norm(o.text+' '+o.value));
            return opts.some(x=>x.includes('route'));
          });
          result.selected.route=choose(routeSel,['route'],['route wan','route']);
          if(!result.selected.route){
            result.selected.route=clickChoice(['route','wan'],true) || clickChoice(['route'],false);
          }
          if(!result.selected.route){
            result.warnings.push('Route WAN control not found; current/default WAN mode retained');
          }
          await sleep(800);

          let pppChoice=selectExactPPPoE();
          if(!pppChoice){
            await sleep(900);
            pppChoice=selectExactPPPoE();
          }
          if(!pppChoice){
            return JSON.stringify({
              ...result,
              error:'Exact PPPoE control not found after selecting Route WAN',
              diagnostics:{selects:optionSummary(),inputs:inputSummary()}
            });
          }
          result.selected.pppoe=pppChoice;
          await sleep(1500);

          const checkedPPP=controls('input[type=radio]:checked').find(e=>/pppoe/.test(ownText(e)));
          const selectedPPP=controls('select').find(s=>{
            const o=s.options[s.selectedIndex];
            return o&&/pppoe/.test(norm(o.text+' '+o.value));
          });
          if(!checkedPPP && !selectedPPP && pppChoice.kind!=='radio-fallback'){
            return JSON.stringify({
              ...result,
              error:'PPPoE control was clicked but active state could not be verified',
              diagnostics:{selects:optionSummary(),inputs:inputSummary()}
            });
          }

          function canonService(s){
            return norm(s).replace(/tr-069/g,'tr069').replace(/[\s-]+/g,'_').replace(/_+/g,'_');
          }
          const wantedService='tr069_voip_internet';
          let serviceSel=controls('select').find(s=>{
            const c=ctx(s);
            const hasWanted=[...s.options].some(o=>{
              const t=canonService(o.text),v=canonService(o.value),both=canonService((o.text||'')+'_'+(o.value||''));
              return t===wantedService || v===wantedService || both.includes(wantedService);
            });
            return hasWanted || /service|wan.*type|connection.*type/.test(c);
          });
          if(serviceSel){
            const opts=[...serviceSel.options];
            const exact=opts.find(o=>canonService(o.text)===wantedService) ||
              opts.find(o=>canonService(o.value)===wantedService);
            const combined=opts.find(o=>canonService((o.text||'')+'_'+(o.value||'')).includes(wantedService));
            const chosen=exact||combined;
            if(chosen){
              serviceSel.value=chosen.value; fire(serviceSel);
              result.selected.service=canonService(chosen.text||chosen.value);
            }
          }
          if(result.selected.service!==wantedService){
            const serviceControls=controls('input[type=checkbox],input[type=radio]');
            function serviceChoice(word){
              const candidates=serviceControls.map(e=>{
                const text=canonService(ownText(e)+' '+ctx(e));
                if(!text.includes(word))return null;
                return {e,text};
              }).filter(Boolean);
              if(!candidates.length)return false;
              const target=candidates.sort((a,b)=>a.text.length-b.text.length)[0].e;
              if(!target.checked)target.click();
              fire(target); return true;
            }
            const tr=serviceChoice('tr069');
            const voip=serviceChoice('voip');
            const internet=serviceChoice('internet');
            if(tr&&voip&&internet){
              result.selected.service=wantedService;
              result.selected.serviceImplementation='three_service_controls';
            }
          }
          if(result.selected.service!==wantedService){
            return JSON.stringify({
              ...result,
              error:'Exact Service Type TR069_VOIP_INTERNET not found',
              diagnostics:{selects:optionSummary(),inputs:inputSummary()}
            });
          }

          await sleep(700);
          const enableWan=findCheckbox(['enable','wan']);
          if(enableWan){check(enableWan,true);result.found.enableWan=true;}
          const vlanCheck=findCheckbox(['vlan']) || findCheckbox(['enable','vlan']);
          if(vlanCheck){check(vlanCheck,true);result.found.vlanEnable=true;}
          await sleep(250);
          const vlanInput=findInput(['vlan','id']) ||
            controls('input').find(e=>/vlan.*id|vid/.test(ctx(e)) && !['checkbox','radio','button','submit'].includes((e.type||'').toLowerCase()));
          if(!vlanInput) return JSON.stringify({...result,error:'VLAN ID field not found',diagnostics:{selects:optionSummary(),inputs:inputSummary()}});
          setv(vlanInput,VLAN); result.found.vlanId=vlanInput.id||vlanInput.name||'field';

          function credentialKey(e){return norm(ctx(e)+' '+(e.id||'')+' '+(e.name||'')+' '+(e.placeholder||''));}
          const editableInputs=controls('input,textarea').filter(e=>{
            const t=(e.type||'').toLowerCase();
            return !['checkbox','radio','button','submit','hidden'].includes(t) && !e.disabled && !e.readOnly;
          });
          const forbiddenUser=/client.?id|ipv4client|dhcp|vendor|host.?name|option.?6?1|connection.?request|acs/;
          let userInput=editableInputs.find(e=>{
            const k=credentialKey(e);
            return !forbiddenUser.test(k) &&
              (/^(username|user name|pppusername|pppoeusername)$/i.test((e.id||e.name||'').trim()) ||
               /ppp.*user|user.*ppp|pppoe.*account|account.*pppoe/.test(k));
          });
          if(!userInput){
            userInput=editableInputs.find(e=>{
              const k=credentialKey(e);
              return !forbiddenUser.test(k) && /user|account/.test(k) && /ppp|pppoe|wan/.test(k);
            });
          }
          if(!userInput){
            return JSON.stringify({...result,error:'Real PPPoE username field not found; DHCP ClientId was excluded',diagnostics:{inputs:inputSummary()}});
          }
          setv(userInput,USER);
          result.found.pppUser=userInput.id||userInput.name||'field';

          const forbiddenPass=/connection.?request|acs|wifi|wlan|login/;
          let passInput=editableInputs.find(e=>{
            const k=credentialKey(e);
            return !forbiddenPass.test(k) &&
              (/^(password|passwd|ppppassword|pppoepassword)$/i.test((e.id||e.name||'').trim()) ||
               /ppp.*pass|pass.*ppp|pppoe.*pass/.test(k));
          });
          if(!passInput){
            passInput=editableInputs.find(e=>{
              const k=credentialKey(e),t=(e.type||'').toLowerCase();
              return !forbiddenPass.test(k) && (t==='password'||/pass/.test(k)) && /ppp|pppoe|wan/.test(k);
            });
          }
          if(!passInput){
            return JSON.stringify({...result,error:'Real PPPoE password field not found after exact PPPoE selection',diagnostics:{inputs:inputSummary()}});
          }
          setv(passInput,PASS);
          result.found.pppPass=passInput.id||passInput.name||'field';

          function exactCheck(e){
            if(!e || e.disabled)return false;
            if(!e.checked)e.click();
            e.checked=true; fire(e); return !!e.checked;
          }
          const bindingState={lan:[],wlan:[],missing:[],disabled:[],unchecked:[]};
          for(let i=1;i<=16;i++){
            const id='IPv4BindLanList'+i;
            const e=allDocs.map(d=>d.getElementById(id)).find(Boolean) ||
              allDocs.flatMap(d=>[...d.querySelectorAll('[name="IPv4BindLanList"]')])[i-1];
            const label=i<=8?'LAN'+i:'SSID'+(i-8);
            if(!e){bindingState.missing.push(label);continue;}
            if(e.disabled){bindingState.disabled.push(label);continue;}
            const ok=exactCheck(e);
            if(ok){
              if(i<=8)bindingState.lan.push(label);else bindingState.wlan.push(label);
            }else{
              bindingState.unchecked.push(label);
            }
          }
          result.found.lanBindings=bindingState.lan.length;
          result.found.wlanBindings=bindingState.wlan.length;
          result.found.bindingControls=bindingState;
          await sleep(250);
          for(let i=1;i<=16;i++){
            const id='IPv4BindLanList'+i;
            const e=allDocs.map(d=>d.getElementById(id)).find(Boolean);
            if(e && !e.disabled && !e.checked){
              const label=i<=8?'LAN'+i:'SSID'+(i-8);
              if(!bindingState.unchecked.includes(label))bindingState.unchecked.push(label);
            }
          }
          if(bindingState.lan.length===0 || bindingState.wlan.length===0 || bindingState.unchecked.length>0){
            return JSON.stringify({...result,error:'LAN/WLAN binding controls did not all become checked',diagnostics:{inputs:inputSummary()}});
          }

          const mtu=controls('input').find(e=>/mtu/.test(ctx(e)));
          if(mtu && !String(mtu.value||'').trim()){setv(mtu,'1492');result.found.mtu='1492';}
          const apply=allDocs.map(d=>d.getElementById('ButtonApply')).find(Boolean) ||
            findButton(['buttonapply']) || findButton(['apply']) || findButton(['submit']) || findButton(['save']);
          if(!apply){
            return JSON.stringify({...result,error:'Exact ButtonApply not found',diagnostics:{selects:optionSummary(),inputs:inputSummary()}});
          }
          window.__tivanWanMessages=[];
          const oldAlert=window.alert;
          const oldConfirm=window.confirm;
          window.alert=function(m){window.__tivanWanMessages.push(String(m||''));};
          window.confirm=function(m){window.__tivanWanMessages.push('CONFIRM: '+String(m||'')); return true;};
          const preSubmit={
            vlan:String(vlanInput.value||''),
            service:result.selected.service,
            pppoe:result.selected.pppoe,
            button:apply.id||apply.name||apply.value||apply.innerText||'ButtonApply'
          };
          result.ok=true;
          result.apply=preSubmit.button;
          result.preSubmit=preSubmit;
          apply.click();
          await sleep(350);
          result.afterClick={
            messages:(window.__tivanWanMessages||[]).slice(0,20),
            url:location.href
          };
          window.alert=oldAlert;
          window.confirm=oldConfirm;
          return JSON.stringify(result);
        })();
        """#
    }

    static let enableRemoteAccess = #"""
    (async function(){
      const sleep=ms=>new Promise(r=>setTimeout(r,ms));
      function norm(s){return (s||'').replace(/\s+/g,' ').trim().toLowerCase();}
      function visible(e){
        if(!e)return false;
        const s=getComputedStyle(e);
        return s.display!=='none'&&s.visibility!=='hidden'&&(e.offsetWidth||e.offsetHeight||e.getClientRects().length);
      }
      function header(e){
        const cell=e.closest('td,th');
        const table=e.closest('table');
        if(!cell||!table)return '';
        const idx=cell.cellIndex;
        for(const row of table.rows){
          if(!row.cells||!row.cells[idx])continue;
          const c=row.cells[idx];
          if(c.tagName==='TH'||row.rowIndex===0)return norm(c.innerText||'');
        }
        return '';
      }
      function rowOf(e){return e.closest('tr')||e.closest('fieldset')||e.closest('li')||e.parentElement;}
      function own(e){
        const labels=[];
        if(e.id){
          try{
            const l=document.querySelector('label[for="'+CSS.escape(e.id)+'"]');
            if(l)labels.push(l.innerText||'');
          }catch(err){}
        }
        if(e.closest('label'))labels.push(e.closest('label').innerText||'');
        return norm(labels.join(' ')+' '+(e.id||'')+' '+(e.name||'')+' '+(e.value||'')+' '+(e.title||''));
      }
      function context(e){
        const row=rowOf(e);
        return norm((row&&row.innerText||'')+' '+own(e)+' '+header(e));
      }
      function proto(s){
        if(/telnet/.test(s)&&!/stelnet/.test(s))return 'telnet';
        if(/stelnet|(^|[^a-z])ssh([^a-z]|$)/.test(s))return 'ssh';
        return '';
      }
      function fire(e){for(const n of ['input','change','blur'])e.dispatchEvent(new Event(n,{bubbles:true}));}
      function setCheck(e,on){
        if(e.disabled)return false;
        const before=!!e.checked;
        if(before!==on)e.click();
        e.checked=on; fire(e);
        return before!==on;
      }
      function selectOption(s,on){
        if(s.disabled)return false;
        const opts=[...s.options];
        const positive=opts.find(o=>/^(1|on|enable|enabled|yes|allow|allowed|lan|local)$/i.test(String(o.value||'').trim()))||
          opts.find(o=>/enable|allow|lan|local/.test(norm(o.text+' '+o.value)));
        const negative=opts.find(o=>/^(0|off|disable|disabled|no|deny|denied|none)$/i.test(String(o.value||'').trim()))||
          opts.find(o=>/disable|deny|wan|remote|internet|public/.test(norm(o.text+' '+o.value)));
        const target=on?positive:negative;
        if(!target)return false;
        const changed=s.value!==target.value;
        s.value=target.value; fire(s); return changed;
      }
      const out={ok:false,foundTelnet:false,foundSSH:false,localEnabled:[],wanDisabled:[],ports:[],changed:0};
      const all=[...document.querySelectorAll('input,select')].filter(visible);
      const protocolRows=[];
      const seenRows=new Set();
      for(const e of all){
        const row=rowOf(e);
        const p=proto(context(e));
        if(!p||!row||seenRows.has(row))continue;
        if(p==='telnet')out.foundTelnet=true;
        if(p==='ssh')out.foundSSH=true;
        protocolRows.push({row,p});
        seenRows.add(row);
      }
      for(const item of protocolRows){
        const row=item.row,p=item.p;
        const controls=[...row.querySelectorAll('input,select')].filter(visible);
        const radioGroups=new Map();
        for(const e of controls){
          const t=(e.type||'').toLowerCase();
          const c=context(e);
          const h=header(e);
          const scopeText=norm(own(e)+' '+h+' '+c);
          const isWAN=/\bwan\b|internet|remote|public/.test(scopeText);
          const isLocal=/\blan\b|local|wlan|wi-?fi/.test(scopeText);
          if(t==='radio'){
            const g=e.name||p+':radio';
            if(!radioGroups.has(g))radioGroups.set(g,[]);
            radioGroups.get(g).push(e);
          } else if(t==='checkbox'){
            if(isWAN&&!isLocal){
              if(setCheck(e,false))out.changed++;
              out.wanDisabled.push(p+':'+(e.id||e.name||'wan'));
            } else {
              if(setCheck(e,true))out.changed++;
              out.localEnabled.push(p+':'+(e.id||e.name||'local'));
            }
          } else if(e.tagName==='SELECT'){
            if(isWAN&&!isLocal){
              if(selectOption(e,false))out.changed++;
              out.wanDisabled.push(p+':'+(e.id||e.name||'wan-select'));
            } else {
              if(selectOption(e,true))out.changed++;
              out.localEnabled.push(p+':'+(e.id||e.name||'local-select'));
            }
          } else if(/port/.test(scopeText)){
            const wanted=p==='ssh'?'22':'23';
            if(!String(e.value||'').trim()||String(e.value||'').trim()==='0'){
              e.value=wanted; fire(e); out.changed++;
              out.ports.push(p+':'+wanted);
            }
          }
        }
        for(const [name, radios] of radioGroups.entries()){
          const withMeta=radios.map(e=>({e,t:norm(own(e)+' '+(e.value||'')+' '+context(e))}));
          const wanGroup=withMeta.some(x=>/\bwan\b|internet|remote|public/.test(x.t));
          let target=null;
          if(wanGroup){
            target=withMeta.find(x=>/disable|deny|off|no/.test(x.t));
          }else{
            target=withMeta.find(x=>/enable|allow|on|yes|lan|local/.test(x.t))||withMeta[0];
          }
          if(target&&!target.e.disabled){
            for(const x of withMeta){
              const should=x===target;
              if(x.e.checked!==should){
                if(should)x.e.click();
                x.e.checked=should; fire(x.e); out.changed++;
              }
            }
            if(wanGroup)out.wanDisabled.push(p+':radio:'+name);
            else out.localEnabled.push(p+':radio:'+name);
          }
        }
      }
      if(!out.foundTelnet&&!out.foundSSH){
        return JSON.stringify({...out,error:'No Telnet/SSH controls on this page'});
      }
      if(out.localEnabled.length===0){
        return JSON.stringify({...out,error:'Protocol controls found but no safe local/LAN enable control was identified'});
      }
      const apply=document.getElementById('ButtonApply')||document.getElementById('Apply')||
        [...document.querySelectorAll('button,input[type=button],input[type=submit],a')]
          .find(e=>/apply|save|submit|ok/i.test((e.innerText||'')+' '+(e.value||'')+' '+(e.id||'')));
      if(out.changed>0&&!apply){
        return JSON.stringify({...out,error:'Remote-access Apply button not found'});
      }
      if(apply){apply.click(); await sleep(300);}
      out.ok=true;
      return JSON.stringify(out);
    })();
    """#
}
