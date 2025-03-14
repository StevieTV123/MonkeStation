
/mob/living/carbon/get_eye_protection()
	. = ..()
	var/obj/item/organ/eyes/E = getorganslot(ORGAN_SLOT_EYES)
	if(!E)
		return INFINITY //Can't get flashed without eyes
	. += E.flash_protect
	if(isclothing(head)) //Adds head protection
		. += head.flash_protect
	if(isclothing(glasses)) //Glasses
		. += glasses.flash_protect
	if(isclothing(wear_mask)) //Mask
		. += wear_mask.flash_protect

/mob/living/carbon/get_ear_protection()
	. = ..()
	var/obj/item/organ/ears/E = getorganslot(ORGAN_SLOT_EARS)
	if(!E)
		return INFINITY
	. += E.bang_protect
	if(isclothing(head)) //Adds head protection
		. += head.bang_protect
	if(isclothing(ears)) //ear slot
		. += ears.bang_protect
	else if(istype(ears, /obj/item/radio/headset))
		var/obj/item/radio/headset/headset_in_ear = ears
		. += headset_in_ear.bang_protect

/mob/living/carbon/is_mouth_covered(head_only = 0, mask_only = 0)
	if( (!mask_only && head && (head.flags_cover & HEADCOVERSMOUTH)) || (!head_only && wear_mask && (wear_mask.flags_cover & MASKCOVERSMOUTH)) )
		return TRUE

/mob/living/carbon/is_eyes_covered(check_glasses = TRUE, check_head = TRUE, check_mask = TRUE)
	if(check_head && head && (head.flags_cover & HEADCOVERSEYES))
		return head
	if(check_mask && wear_mask && (wear_mask.flags_cover & MASKCOVERSEYES))
		return wear_mask
	if(check_glasses && glasses && (glasses.flags_cover & GLASSESCOVERSEYES))
		return glasses

/mob/living/carbon/check_projectile_dismemberment(obj/item/projectile/P, def_zone)
	var/obj/item/bodypart/affecting = get_bodypart(def_zone)
	if(affecting && affecting.dismemberable && affecting.get_damage() >= (affecting.max_damage - P.dismemberment))
		affecting.dismember(P.damtype)

/mob/living/carbon/proc/can_catch_item(skip_throw_mode_check)
	. = FALSE
	if(!skip_throw_mode_check && !throw_mode) //monkestation edit
		return
	if(get_active_held_item())
		return
	if(HAS_TRAIT(src, TRAIT_HANDS_BLOCKED))
		return
	return TRUE

/mob/living/carbon/hitby(atom/movable/AM, skipcatch, hitpush = TRUE, blocked = FALSE, datum/thrownthing/throwingdatum)
	if(!skipcatch)	//ugly, but easy
		if(can_catch_item())
			if(istype(AM, /obj/item))
				var/obj/item/I = AM
				if(isturf(I.loc))
					I.attack_hand(src)
					if(get_active_held_item() == I) //if our attack_hand() picks up the item...
						visible_message("<span class='warning'>[src] catches [I]!</span>", \
										"<span class='userdanger'>You catch [I] in mid-air!</span>")
						throw_mode_off(THROW_MODE_TOGGLE) //monkestation edit
						return 1
	..(AM, skipcatch, hitpush, blocked, throwingdatum)


/mob/living/carbon/attacked_by(obj/item/I, mob/living/user)
	var/obj/item/bodypart/affecting
	affecting = get_bodypart(check_zone(user.zone_selected))
	if(!affecting) //missing limb? we select the first bodypart (you can never have zero, because of chest)
		affecting = bodyparts[1]
	SEND_SIGNAL(I, COMSIG_ITEM_ATTACK_ZONE, src, user, affecting)
	send_item_attack_message(I, user, parse_zone(affecting.body_zone))
	if(I.force)
		apply_damage(I.force, I.damtype, affecting)
		if(I.damtype == BRUTE && (IS_ORGANIC_LIMB(affecting)))
			if(I.is_sharp() || I.force >= 10)
				I.add_mob_blood(src)
				var/turf/location = get_turf(src)
				add_splatter_floor(location)
				if(get_dist(user, src) <= 1)	//people with TK won't get smeared with blood
					user.add_mob_blood(src)
					if(ishuman(user))
						var/mob/living/carbon/human/dirtyboy = user
						dirtyboy.adjust_hygiene(-10)
				if(affecting.body_zone == BODY_ZONE_HEAD)
					if(wear_mask)
						wear_mask.add_mob_blood(src)
						update_inv_wear_mask()
					if(wear_neck)
						wear_neck.add_mob_blood(src)
						update_inv_neck()
					if(head)
						head.add_mob_blood(src)
						update_inv_head()

		//dismemberment
		var/dismemberthreshold = (((affecting.max_damage * 2) / max(I.is_sharp(), 0.5)) - (affecting.get_damage() + ((I.w_class - 3) * 10) + ((I.attack_weight - 1) * 15)))
		if(HAS_TRAIT(src, TRAIT_EASYDISMEMBER))
			dismemberthreshold -= 50
		if(I.is_sharp())
			dismemberthreshold = min(((affecting.max_damage * 2) - affecting.get_damage()), dismemberthreshold) //makes it so limbs wont become immune to being dismembered if the item is sharp
			if(stat == DEAD)
				dismemberthreshold = dismemberthreshold / 3
		if(I.force >= dismemberthreshold && I.force >= 10)
			if(affecting.dismember(I.damtype))
				I.add_mob_blood(src)
				playsound(get_turf(src), I.get_dismember_sound(), 80, 1)
		return TRUE //successful attack

/mob/living/carbon/attack_hulk(mob/living/carbon/human/user, does_attack_animation = 0)
	if(user.a_intent == INTENT_HARM)
		if(HAS_TRAIT(user, TRAIT_PACIFISM))
			to_chat(user, "<span class='notice'>You don't want to hurt [src]!</span>")
			return FALSE
		..(user, 1)
		playsound(loc, "punch", 25, 1, -1)
		visible_message("<span class='danger'>[user] punches [src]!</span>", \
			"<span class='userdanger'>[user] punches you!</span>", null, COMBAT_MESSAGE_RANGE)
		adjustBruteLoss(20)
		return TRUE


/mob/living/carbon/attack_drone(mob/living/simple_animal/drone/user)
	return //so we don't call the carbon's attack_hand().

//ATTACK HAND IGNORING PARENT RETURN VALUE
/mob/living/carbon/attack_hand(mob/living/carbon/human/user)

	if(SEND_SIGNAL(src, COMSIG_ATOM_ATTACK_HAND, user) & COMPONENT_CANCEL_ATTACK_CHAIN)
		. = TRUE

	for(var/thing in diseases)
		var/datum/disease/D = thing
		if(D.spread_flags & DISEASE_SPREAD_CONTACT_SKIN)
			user.ContactContractDisease(D)

	for(var/thing in user.diseases)
		var/datum/disease/D = thing
		if(D.spread_flags & DISEASE_SPREAD_CONTACT_SKIN)
			ContactContractDisease(D)

	for(var/datum/surgery/S in surgeries)
		if(body_position == LYING_DOWN || !S.lying_required)
			if(user.a_intent == INTENT_HELP || user.a_intent == INTENT_DISARM)
				if(S.next_step(user, user.a_intent))
					return 1
	return 0


/mob/living/carbon/attack_paw(mob/living/carbon/monkey/M)

	if(can_inject(M, TRUE))
		for(var/thing in diseases)
			var/datum/disease/D = thing
			if((D.spread_flags & DISEASE_SPREAD_CONTACT_SKIN) && prob(85))
				M.ContactContractDisease(D)

	for(var/thing in M.diseases)
		var/datum/disease/D = thing
		if(D.spread_flags & DISEASE_SPREAD_CONTACT_SKIN)
			ContactContractDisease(D)

	if(M.a_intent == INTENT_HELP)
		help_shake_act(M)
		return 0

	if(..() && can_inject(M, TRUE)) //successful monkey bite.
		for(var/thing in M.diseases)
			var/datum/disease/D = thing
			ForceContractDisease(D)
		return 1


/mob/living/carbon/attack_slime(mob/living/simple_animal/slime/M)
	if(..()) //successful slime attack
		if(M.powerlevel > 0)
			M.powerlevel--
			visible_message("<span class='danger'>The [M.name] has shocked [src]!</span>", \
				"<span class='userdanger'>The [M.name] has shocked you!</span>")
			do_sparks(5, TRUE, src)
			Knockdown(M.powerlevel*5)
			if(stuttering < M.powerlevel)
				stuttering = M.powerlevel
			if(M.transformeffects & SLIME_EFFECT_ORANGE)
				adjust_fire_stacks(2)
				IgniteMob()
			adjustFireLoss(M.powerlevel * 3)
			updatehealth()
		return TRUE

/mob/living/carbon/proc/dismembering_strike(mob/living/attacker, dam_zone)
	if(!attacker.limb_destroyer)
		return dam_zone
	var/obj/item/bodypart/affecting
	if(dam_zone && attacker.client)
		affecting = get_bodypart(ran_zone(dam_zone))
	else
		var/list/things_to_ruin = shuffle(bodyparts.Copy())
		for(var/B in things_to_ruin)
			var/obj/item/bodypart/bodypart = B
			if(bodypart.body_zone == BODY_ZONE_HEAD || bodypart.body_zone == BODY_ZONE_CHEST)
				continue
			if(!affecting || ((affecting.get_damage() / affecting.max_damage) < (bodypart.get_damage() / bodypart.max_damage)))
				affecting = bodypart
	if(affecting)
		dam_zone = affecting.body_zone
		if(affecting.get_damage() >= affecting.max_damage)
			affecting.dismember()
			return null
		return affecting.body_zone
	return dam_zone


/mob/living/carbon/blob_act(obj/structure/blob/B)
	if (stat == DEAD)
		return
	else
		show_message("<span class='userdanger'>The blob attacks!</span>")
		adjustBruteLoss(10)

/mob/living/carbon/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_CONTENTS)
		return
	for(var/X in internal_organs)
		var/obj/item/organ/O = X
		O.emp_act(severity)

///Adds to the parent by also adding functionality to propagate shocks through pulling and doing some fluff effects.
/mob/living/carbon/electrocute_act(shock_damage, source, siemens_coeff = 1, flags = NONE, override = 0)
	. = ..()
	if(!.)
		return
	//Propagation through pulling, fireman carry
	if(!(flags & SHOCK_ILLUSION))
		if(undergoing_cardiac_arrest())
			set_heartattack(FALSE)
		var/list/shocking_queue = list()
		if(iscarbon(pulling) && source != pulling)
			shocking_queue += pulling
		if(iscarbon(pulledby) && source != pulledby)
			shocking_queue += pulledby
		if(iscarbon(buckled) && source != buckled)
			shocking_queue += buckled
		for(var/mob/living/carbon/carried in buckled_mobs)
			if(source != carried)
				shocking_queue += carried
		//Found our victims, now lets shock them all
		for(var/victim in shocking_queue)
			var/mob/living/carbon/C = victim
			C.electrocute_act(shock_damage*0.75, src, 1, flags)
	//Stun
	var/should_stun = (!(flags & SHOCK_TESLA) || siemens_coeff > 0.5) && !(flags & SHOCK_NOSTUN)
	if(should_stun)
		Paralyze(40)
	spawn(20)
		jitteriness = max(jitteriness - 990, 10) //Still jittery, but vastly less
	if(override)
		return override
	else
		return shock_damage

/mob/living/carbon/proc/help_shake_act(mob/living/carbon/M)
	if(on_fire)
		to_chat(M, "<span class='warning'>You can't put [p_them()] out with just your bare hands!</span>")
		return

	if(M == src && check_self_for_injuries())
		return

	if(body_position == LYING_DOWN)
		if(buckled)
			to_chat(M, "<span class='warning'>You need to unbuckle [src] first to do that!")
			return
		M.visible_message("<span class='notice'>[M] shakes [src] trying to get [p_them()] up!</span>", \
						"<span class='notice'>You shake [src] trying to get [p_them()] up!</span>")
	else if(M.zone_selected == BODY_ZONE_CHEST)
		M.visible_message("<span class='notice'>[M] hugs [src] to make [p_them()] feel better!</span>", \
					"<span class='notice'>You hug [src] to make [p_them()] feel better!</span>")
		SEND_SIGNAL(src, COMSIG_ADD_MOOD_EVENT, "hug", /datum/mood_event/hug)
		if(HAS_TRAIT(M, TRAIT_FRIENDLY))
			var/datum/component/mood/mood = M.GetComponent(/datum/component/mood)
			if (mood.sanity >= SANITY_GREAT)
				SEND_SIGNAL(src, COMSIG_ADD_MOOD_EVENT, "friendly_hug", /datum/mood_event/besthug, M)
			else if (mood.sanity >= SANITY_DISTURBED)
				SEND_SIGNAL(src, COMSIG_ADD_MOOD_EVENT, "friendly_hug", /datum/mood_event/betterhug, M)
		for(var/datum/brain_trauma/trauma in M.get_traumas())
			trauma.on_hug(M, src)
	else if(M.zone_selected == BODY_ZONE_HEAD)
		M.visible_message("<span class='notice'>[M] pats [src] on the head.</span>", \
					"<span class='notice'>You pat [src] on the head.</span>")
		SEND_SIGNAL(src, COMSIG_ADD_MOOD_EVENT, "headpat", /datum/mood_event/headpat, M)
	else if((M.zone_selected == BODY_ZONE_L_ARM) || (M.zone_selected == BODY_ZONE_R_ARM))
		if(!get_bodypart(check_zone(M.zone_selected)))
			to_chat(M, "<span class='warning'>[src] does not have a [M.zone_selected == BODY_ZONE_L_ARM ? "left" : "right"] arm!</span>")
		else
			M.visible_message("<span class='notice'>[M] shakes [src]'s hand.</span>", \
						"<span class='notice'>You shake [src]'s hand.</span>")
	else if(M.zone_selected == BODY_ZONE_PRECISE_GROIN)
		to_chat(M, "<span class='warning'>ERP is not allowed on this server!</span>")
	AdjustStun(-60)
	AdjustKnockdown(-60)
	AdjustUnconscious(-60)
	AdjustSleeping(-100)
	AdjustParalyzed(-60)
	AdjustImmobilized(-60)
	set_resting(FALSE)

	playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)

/// Check ourselves to see if we've got any shrapnel, return true if we do. This is a much simpler version of what humans do, we only indicate we're checking ourselves if there's actually shrapnel
/mob/living/carbon/proc/check_self_for_injuries()
	if(stat == DEAD || stat == UNCONSCIOUS)
		return

	var/embeds = FALSE
	for(var/X in bodyparts)
		var/obj/item/bodypart/LB = X
		for(var/obj/item/I in LB.embedded_objects)
			if(!embeds)
				embeds = TRUE
				// this way, we only visibly try to examine ourselves if we have something embedded, otherwise we'll still hug ourselves :)
				visible_message("<span class='notice'>[src] examines [p_them()]self.</span>", \
					"<span class='notice'>You check yourself for shrapnel.</span>")
			if(I.isEmbedHarmless())
				to_chat(src, "\t <a href='?src=[REF(src)];embedded_object=[REF(I)];embedded_limb=[REF(LB)]' class='warning'>There is \a [I] stuck to your [LB.name]!</a>")
			else
				to_chat(src, "\t <a href='?src=[REF(src)];embedded_object=[REF(I)];embedded_limb=[REF(LB)]' class='warning'>There is \a [I] embedded in your [LB.name]!</a>")

	return embeds

/mob/living/carbon/flash_act(intensity = 1, override_blindness_check = 0, affect_silicon = 0, visual = 0)
	if(NOFLASH in dna?.species?.species_traits)
		return
	var/obj/item/organ/eyes/eyes = getorganslot(ORGAN_SLOT_EYES)
	if(!eyes || HAS_TRAIT(src, TRAIT_BLIND)) //can't flash what can't see!
		return
	. = ..()

	var/damage = intensity - get_eye_protection()
	if(.) // we've been flashed
		if(visual)
			return
		apply_status_effect(/datum/status_effect/flashed)
		switch(damage)
			if(1)
				to_chat(src, "<span class='warning'>Your eyes sting a little.</span>")
				if(prob(40))
					eyes.applyOrganDamage(1)

			if (2)
				to_chat(src, "<span class='warning'>Your eyes burn.</span>")
				eyes.applyOrganDamage(rand(2, 4))

			if(3 to INFINITY)
				to_chat(src, "<span class='warning'>Your eyes itch and burn severely!</span>")
				eyes.applyOrganDamage(rand(12, 16))

		if(eyes.damage > 10)
			blind_eyes(damage)
			blur_eyes(damage * rand(3, 6))

			if(eyes.damage > 20)
				if(prob(eyes.damage - 20))
					if(!HAS_TRAIT(src, TRAIT_NEARSIGHT))
						to_chat(src, "<span class='warning'>Your eyes start to burn badly!</span>")
					become_nearsighted(EYE_DAMAGE)

				else if(prob(eyes.damage - 25))
					if(!HAS_TRAIT(src, TRAIT_BLIND))
						to_chat(src, "<span class='warning'>You can't see anything!</span>")
					eyes.applyOrganDamage(eyes.maxHealth)

			else
				to_chat(src, "<span class='warning'>Your eyes are really starting to hurt. This can't be good for you!</span>")
		if(has_bane(BANE_LIGHT))
			mind.disrupt_spells(-500)
		return 1
	else if(damage == 0) // just enough protection
		if(prob(20))
			to_chat(src, "<span class='notice'>Something bright flashes in the corner of your vision!</span>")
		if(has_bane(BANE_LIGHT))
			mind.disrupt_spells(0)


/mob/living/carbon/soundbang_act(intensity = 1, stun_pwr = 20, damage_pwr = 5, deafen_pwr = 15)
	var/list/reflist = list(intensity) // Need to wrap this in a list so we can pass a reference
	SEND_SIGNAL(src, COMSIG_CARBON_SOUNDBANG, reflist)
	intensity = reflist[1]
	var/ear_safety = get_ear_protection()
	var/obj/item/organ/ears/ears = getorganslot(ORGAN_SLOT_EARS)
	var/effect_amount = intensity - ear_safety
	if(effect_amount > 0)
		if(stun_pwr)
			if(!ears.deaf)
				Paralyze((stun_pwr*effect_amount)*0.1)
			Knockdown(stun_pwr*effect_amount)

		if(istype(ears) && (deafen_pwr || damage_pwr))
			var/ear_damage = damage_pwr * effect_amount
			var/deaf = deafen_pwr * effect_amount
			adjustEarDamage(ear_damage,deaf)

			if(ears.damage >= 15)
				to_chat(src, "<span class='warning'>Your ears start to ring badly!</span>")
				if(prob(ears.damage - 5))
					to_chat(src, "<span class='userdanger'>You can't hear anything!</span>")
					ears.damage = min(ears.damage, ears.maxHealth)
					// you need earmuffs, inacusiate, or replacement
			else if(ears.damage >= 5)
				to_chat(src, "<span class='warning'>Your ears start to ring!</span>")
			SEND_SOUND(src, sound('sound/weapons/flash_ring.ogg',0,1,0,250))
		return effect_amount //how soundbanged we are


/mob/living/carbon/damage_clothes(damage_amount, damage_type = BRUTE, damage_flag = 0, def_zone)
	if(damage_type != BRUTE && damage_type != BURN)
		return
	damage_amount *= 0.5 //0.5 multiplier for balance reason, we don't want clothes to be too easily destroyed
	if(!def_zone || def_zone == BODY_ZONE_HEAD)
		var/obj/item/clothing/hit_clothes
		if(wear_mask)
			hit_clothes = wear_mask
		if(wear_neck)
			hit_clothes = wear_neck
		if(head)
			hit_clothes = head
		if(hit_clothes)
			hit_clothes.take_damage(damage_amount, damage_type, damage_flag, 0)

/mob/living/carbon/can_hear()
	. = FALSE
	var/obj/item/organ/ears/ears = getorganslot(ORGAN_SLOT_EARS)
	if(istype(ears) && !ears.deaf)
		. = TRUE

/mob/living/carbon/extrapolator_act(mob/user, var/obj/item/extrapolator/E, scan = TRUE)
	if(istype(E) && diseases.len)
		if(scan)
			E.scan(src, diseases, user)
		else
			E.extrapolate(src, diseases, user)
		return TRUE
	else
		return FALSE

/mob/living/carbon/adjustOxyLoss(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(isnull(.))
		return
	if(. <= 50)
		if(getOxyLoss() > 50)
			ADD_TRAIT(src, TRAIT_KNOCKEDOUT, OXYLOSS_TRAIT)
	else if(getOxyLoss() <= 50)
		REMOVE_TRAIT(src, TRAIT_KNOCKEDOUT, OXYLOSS_TRAIT)


/mob/living/carbon/setOxyLoss(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(isnull(.))
		return
	if(. <= 50)
		if(getOxyLoss() > 50)
			ADD_TRAIT(src, TRAIT_KNOCKEDOUT, OXYLOSS_TRAIT)
	else if(getOxyLoss() <= 50)
		REMOVE_TRAIT(src, TRAIT_KNOCKEDOUT, OXYLOSS_TRAIT)
