using ChainsawManMod.Common.Systems;
using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Hardmode boss. A huge, slow mass of flesh that drifts toward the player, bursts rings of blood,
	// and spits out Eternity Fleshlings. It regenerates while any Fleshlings are alive, so kill them fast.
	[AutoloadBossHead]
	public class EternityDevil : ModNPC
	{
		private const int FrameCount = 4;
		private const int MaxFleshlings = 5;

		private ref float Timer => ref NPC.ai[0];
		private ref float SpawnTimer => ref NPC.ai[1];

		private bool PhaseTwo => NPC.life < NPC.lifeMax / 2;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
		}

		public override void SetDefaults() {
			NPC.width = 150;
			NPC.height = 150;
			NPC.damage = 70;
			NPC.defense = 35;
			NPC.lifeMax = 40000;
			NPC.HitSound = SoundID.NPCHit9;
			NPC.DeathSound = SoundID.NPCDeath11;
			NPC.knockBackResist = 0f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.value = Item.buyPrice(gold: 20);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 10f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicID.Boss3;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				NPC.velocity.Y += 0.2f; // sink away
				NPC.EncourageDespawn(10);
				return;
			}

			NPC.direction = NPC.spriteDirection = player.Center.X > NPC.Center.X ? 1 : -1;
			Timer++;

			// Slow, relentless drift; speeds up if the player runs far away.
			float distance = Vector2.Distance(player.Center, NPC.Center);
			float speed = distance > 900f ? 9f : PhaseTwo ? 3.5f : 2.5f;
			DevilUtils.FlyToward(NPC, player.Center, speed, 30f);

			// Rings of blood.
			int ringRate = PhaseTwo ? 70 : 100;
			if (Timer % ringRate == 0) {
				int bolts = PhaseTwo ? 14 : 10;
				float offset = Main.rand.NextFloat(MathHelper.TwoPi);
				for (int i = 0; i < bolts; i++) {
					Vector2 velocity = (offset + MathHelper.TwoPi * i / bolts).ToRotationVector2() * 7f;
					DevilUtils.Shoot(NPC, NPC.Center, velocity, ModContent.ProjectileType<BloodBolt>(), NPC.damage / 2);
				}
				SoundEngine.PlaySound(SoundID.NPCDeath11, NPC.Center);
			}

			// Spit out Fleshlings.
			SpawnTimer++;
			if (SpawnTimer >= (PhaseTwo ? 240 : 360)) {
				SpawnTimer = 0f;
				if (DevilUtils.CountActive(ModContent.NPCType<EternityFleshling>()) < MaxFleshlings) {
					for (int i = 0; i < 3; i++) {
						DevilUtils.SpawnMinion(NPC, ModContent.NPCType<EternityFleshling>(), NPC.Center + Main.rand.NextVector2Circular(60f, 60f));
					}
				}
			}

			// Regenerate while Fleshlings are alive (server decides, then syncs).
			if (Timer % 30 == 0 && Main.netMode != NetmodeID.MultiplayerClient) {
				int fleshlings = DevilUtils.CountActive(ModContent.NPCType<EternityFleshling>());
				if (fleshlings > 0 && NPC.life < NPC.lifeMax) {
					NPC.life = System.Math.Min(NPC.lifeMax, NPC.life + fleshlings * 60);
					NPC.netUpdate = true;
				}
			}
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 10) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override bool CanHitPlayer(Player target, ref int cooldownSlot) {
			cooldownSlot = ImmunityCooldownID.Bosses;
			return true;
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 25, 40));
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofNight, 1, 10, 20));
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofLight, 1, 10, 20));
		}

		public override void BossLoot(ref int potionType) {
			potionType = ItemID.GreaterHealingPotion;
		}

		public override void OnKill() {
			NPC.SetEventFlagCleared(ref DownedDevilSystem.downedEternityDevil, -1);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.EternityDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
