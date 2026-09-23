using ChainsawManMod.Common.Systems;
using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using System;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Pre-Hardmode boss. A huge walking devil that leaps at the player, slams the ground to spray blood,
	// and keeps raising Zombie Devil Minions. Below half health it gets faster and attacks more often.
	[AutoloadBossHead]
	public class ZombieDevil : ModNPC
	{
		private const int FrameCount = 4;
		private const int MaxMinions = 6;

		// ai[0]: leap timer, ai[1]: 1 while mid-leap, ai[2]: minion timer, ai[3]: ticks spent too far from the player
		private ref float LeapTimer => ref NPC.ai[0];
		private ref float Leaping => ref NPC.ai[1];
		private ref float MinionTimer => ref NPC.ai[2];
		private ref float FarTimer => ref NPC.ai[3];

		private bool PhaseTwo => NPC.life < NPC.lifeMax / 2;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
		}

		public override void SetDefaults() {
			NPC.width = 80;
			NPC.height = 140;
			NPC.damage = 30;
			NPC.defense = 12;
			NPC.lifeMax = 3500;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath10;
			NPC.knockBackResist = 0f;
			NPC.value = Item.buyPrice(gold: 5);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 10f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicID.Boss1;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				// Everyone is dead: wander off and despawn.
				NPC.velocity.X = MathHelper.Lerp(NPC.velocity.X, -NPC.direction * 4f, 0.05f);
				NPC.EncourageDespawn(10);
				return;
			}

			NPC.TargetClosest(true); // also faces the player
			NPC.spriteDirection = NPC.direction;
			bool onGround = NPC.velocity.Y == 0f;

			if (onGround) {
				if (Leaping == 1f) {
					Slam();
					Leaping = 0f;
				}

				float speed = PhaseTwo ? 3.2f : 2.2f;
				NPC.velocity.X = MathHelper.Lerp(NPC.velocity.X, NPC.direction * speed, 0.1f);

				// Hop over walls, or when the player is standing well above.
				if (NPC.collideX || player.Bottom.Y < NPC.Top.Y - 48f) {
					NPC.velocity.Y = -9f;
				}

				LeapTimer++;
				if (LeapTimer >= (PhaseTwo ? 200 : 320)) {
					LeapTimer = 0f;
					Leaping = 1f;
					float dx = player.Center.X - NPC.Center.X;
					NPC.velocity.X = MathHelper.Clamp(dx / 40f, -11f, 11f);
					NPC.velocity.Y = -12f;
					SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
					NPC.netUpdate = true;
				}
			}

			SummonMinions();
			KeepUp(player);
		}

		// Landing from a leap: shake, blood spray and a fan of falling blood bolts.
		private void Slam() {
			SoundEngine.PlaySound(SoundID.Item14, NPC.Bottom);
			for (int i = 0; i < 40; i++) {
				Dust.NewDust(NPC.BottomLeft - new Vector2(0f, 8f), NPC.width, 8, DustID.Blood, Main.rand.NextFloat(-6f, 6f), Main.rand.NextFloat(-6f, -1f));
			}

			if (Main.netMode == NetmodeID.MultiplayerClient) {
				return;
			}

			int bolts = PhaseTwo ? 7 : 5;
			int damage = NPC.damage / 2;
			for (int i = 0; i < bolts; i++) {
				float angle = MathHelper.Lerp(-MathHelper.PiOver2 - 1f, -MathHelper.PiOver2 + 1f, i / (float)(bolts - 1));
				Vector2 velocity = angle.ToRotationVector2() * 8f;
				Projectile.NewProjectile(NPC.GetSource_FromAI(), NPC.Top + new Vector2(0f, 20f), velocity, ModContent.ProjectileType<BloodBolt>(), damage, 0f, Main.myPlayer, ai0: 1f);
			}
		}

		private void SummonMinions() {
			MinionTimer++;
			if (MinionTimer < (PhaseTwo ? 300 : 480)) {
				return;
			}
			MinionTimer = 0f;

			if (Main.netMode == NetmodeID.MultiplayerClient || CountActive(ModContent.NPCType<ZombieDevilMinion>()) >= MaxMinions) {
				return;
			}

			for (int i = -1; i <= 1; i += 2) {
				NPC minion = NPC.NewNPCDirect(NPC.GetSource_FromAI(), (int)NPC.Center.X + i * 60, (int)NPC.Bottom.Y, ModContent.NPCType<ZombieDevilMinion>());
				if (minion.whoAmI < Main.maxNPCs && Main.netMode == NetmodeID.Server) {
					NetMessage.SendData(MessageID.SyncNPC, number: minion.whoAmI);
				}
			}
		}

		// Ground bosses can get stuck. If the player has been far away for a few seconds, pop back in near them.
		private void KeepUp(Player player) {
			if (Vector2.Distance(NPC.Center, player.Center) > 1400f) {
				FarTimer++;
			}
			else {
				FarTimer = 0f;
			}

			if (FarTimer > 180f && Main.netMode != NetmodeID.MultiplayerClient) {
				FarTimer = 0f;
				NPC.Center = player.Center + new Vector2(-player.direction * 400f, -300f);
				NPC.velocity = Vector2.Zero;
				NPC.netUpdate = true;
			}
		}

		private static int CountActive(int type) {
			int count = 0;
			foreach (NPC other in Main.ActiveNPCs) {
				if (other.type == type) {
					count++;
				}
			}
			return count;
		}

		public override void FindFrame(int frameHeight) {
			if (NPC.velocity.Y != 0f) {
				NPC.frame.Y = frameHeight; // mid-stride pose while airborne
				return;
			}

			NPC.frameCounter += Math.Abs(NPC.velocity.X) * 0.5f + 0.2f;
			if (NPC.frameCounter >= 6) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override bool CanHitPlayer(Player target, ref int cooldownSlot) {
			cooldownSlot = ImmunityCooldownID.Bosses;
			return true;
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 15, 25));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<ChainsawArm>(), 3));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<PochitasHeart>(), 4));
		}

		public override void BossLoot(ref int potionType) {
			potionType = ItemID.LesserHealingPotion;
		}

		public override void OnKill() {
			NPC.SetEventFlagCleared(ref DownedDevilSystem.downedZombieDevil, -1);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.ZombieDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			int count = NPC.life <= 0 ? 80 : 6;
			for (int i = 0; i < count; i++) {
				Dust.NewDust(NPC.position, NPC.width, NPC.height, DustID.Blood, hit.HitDirection * 2f, -2f);
			}
		}
	}
}
