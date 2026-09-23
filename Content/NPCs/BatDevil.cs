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
	// Hardmode flying boss. Circles above the player firing spreads of blood bolts, then winds up and dashes.
	// Below half health it fires wider spreads, dashes twice in a row and calls Devil Bats.
	[AutoloadBossHead]
	public class BatDevil : ModNPC
	{
		private const int FrameCount = 4;
		private const int MaxBats = 6;

		private const int StateHover = 0;
		private const int StateWindUp = 1;
		private const int StateDash = 2;

		private ref float Timer => ref NPC.ai[0];
		private ref float State => ref NPC.ai[1];
		private ref float BatTimer => ref NPC.ai[2];
		private ref float DashesLeft => ref NPC.ai[3];

		private bool PhaseTwo => NPC.life < NPC.lifeMax / 2;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
		}

		public override void SetDefaults() {
			NPC.width = 120;
			NPC.height = 90;
			NPC.damage = 60;
			NPC.defense = 30;
			NPC.lifeMax = 28000;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.knockBackResist = 0f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.value = Item.buyPrice(gold: 15);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 10f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicID.Boss2;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				// Everyone is dead: fly away and despawn.
				NPC.velocity.Y -= 0.2f;
				NPC.EncourageDespawn(10);
				return;
			}

			NPC.direction = NPC.spriteDirection = player.Center.X > NPC.Center.X ? 1 : -1;
			Timer++;

			switch ((int)State) {
				case StateHover:
					Hover(player);
					break;
				case StateWindUp:
					WindUp(player);
					break;
				case StateDash:
					Dash();
					break;
			}

			CallBats();
			NPC.rotation = NPC.velocity.X * 0.02f;
		}

		private void Hover(Player player) {
			// Sway from side to side above the player.
			Vector2 target = player.Center + new Vector2((float)Math.Sin(Timer / 50f) * 320f, -260f);
			float speed = PhaseTwo ? 13f : 10f;
			Vector2 move = (target - NPC.Center).SafeNormalize(Vector2.Zero) * Math.Min(speed, Vector2.Distance(target, NPC.Center) / 10f + 2f);
			NPC.velocity = (NPC.velocity * 19f + move) / 20f;

			int fireRate = PhaseTwo ? 35 : 50;
			if (Timer % fireRate == 0 && Main.netMode != NetmodeID.MultiplayerClient) {
				int bolts = PhaseTwo ? 5 : 3;
				Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY);
				for (int i = 0; i < bolts; i++) {
					float spread = MathHelper.ToRadians(12f) * (i - (bolts - 1) / 2f);
					Projectile.NewProjectile(NPC.GetSource_FromAI(), NPC.Center, aim.RotatedBy(spread) * 9f, ModContent.ProjectileType<BloodBolt>(), NPC.damage / 2, 0f, Main.myPlayer);
				}
			}

			if (Timer >= 300) {
				SetState(StateWindUp);
				DashesLeft = PhaseTwo ? 2 : 1;
			}
		}

		private void WindUp(Player player) {
			NPC.velocity *= 0.9f;
			Dust.NewDust(NPC.position, NPC.width, NPC.height, DustID.Blood, 0f, 0f);

			if (Timer >= 40) {
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
				NPC.velocity = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY) * (PhaseTwo ? 24f : 20f);
				SetState(StateDash);
			}
		}

		private void Dash() {
			if (Timer >= 40) {
				DashesLeft--;
				SetState(DashesLeft > 0 ? StateWindUp : StateHover);
			}
		}

		private void SetState(int state) {
			State = state;
			Timer = 0f;
			NPC.netUpdate = true;
		}

		private void CallBats() {
			if (!PhaseTwo) {
				return;
			}

			BatTimer++;
			if (BatTimer < 420) {
				return;
			}
			BatTimer = 0f;

			if (Main.netMode == NetmodeID.MultiplayerClient || DevilUtils.CountActive(ModContent.NPCType<DevilBat>()) >= MaxBats) {
				return;
			}

			for (int i = 0; i < 2; i++) {
				NPC bat = NPC.NewNPCDirect(NPC.GetSource_FromAI(), (int)NPC.Center.X, (int)NPC.Center.Y, ModContent.NPCType<DevilBat>());
				if (bat.whoAmI < Main.maxNPCs && Main.netMode == NetmodeID.Server) {
					NetMessage.SendData(MessageID.SyncNPC, number: bat.whoAmI);
				}
			}
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter += State == StateDash ? 2 : 1;
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
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 20, 30));
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofFlight, 1, 15, 25));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<RevvedStarterCord>(), 4));
		}

		public override void BossLoot(ref int potionType) {
			potionType = ItemID.GreaterHealingPotion;
		}

		public override void OnKill() {
			NPC.SetEventFlagCleared(ref DownedDevilSystem.downedBatDevil, -1);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.BatDevil")
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
